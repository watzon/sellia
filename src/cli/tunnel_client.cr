require "http/web_socket"
require "uri"
require "log"
require "../core/protocol"
require "./local_proxy"
require "./config"

module Sellia::CLI
  # TunnelClient manages a WebSocket connection to the tunnel server
  # and forwards incoming requests to a local service.
  class TunnelClient
    Log = ::Log.for(self)

    # Configuration
    property server_url : String
    property api_key : String?
    property local_port : Int32
    property local_host : String
    property subdomain : String?
    property auth : String?

    # State
    property public_url : String?
    property tunnel_id : String?
    getter connected : Bool = false
    getter authenticated : Bool = false

    # Auto-reconnect settings
    property auto_reconnect : Bool = true
    property reconnect_delay : Time::Span = 3.seconds
    property max_reconnect_attempts : Int32 = 10

    @socket : HTTP::WebSocket?
    @proxy : LocalProxy
    @running : Bool = false
    @reconnect_attempts : Int32 = 0

    # Storage for in-flight requests
    @pending_requests : Hash(String, Protocol::Messages::RequestStart) = {} of String => Protocol::Messages::RequestStart
    @request_bodies : Hash(String, IO::Memory) = {} of String => IO::Memory

    # Callbacks
    @on_connect : (String ->)?
    @on_request : (Protocol::Messages::RequestStart ->)?
    @on_disconnect : (->)?
    @on_error : (String ->)?

    def initialize(
      @server_url : String,
      @local_port : Int32,
      @api_key : String? = nil,
      @local_host : String = "localhost",
      @subdomain : String? = nil,
      @auth : String? = nil
    )
      @proxy = LocalProxy.new(@local_host, @local_port)
    end

    # Set callback for when tunnel is connected and ready
    def on_connect(&block : String ->)
      @on_connect = block
    end

    # Set callback for each incoming request
    def on_request(&block : Protocol::Messages::RequestStart ->)
      @on_request = block
    end

    # Set callback for disconnection
    def on_disconnect(&block : ->)
      @on_disconnect = block
    end

    # Set callback for errors
    def on_error(&block : String ->)
      @on_error = block
    end

    # Start the tunnel client - connects and begins processing
    def start
      @running = true
      @reconnect_attempts = 0
      connect
    end

    # Stop the tunnel client and close connection
    def stop
      @running = false
      @connected = false
      @authenticated = false
      @socket.try(&.close)
      @socket = nil
    end

    # Returns true if the client is currently running (may be reconnecting)
    def running? : Bool
      @running
    end

    private def connect
      return unless @running

      uri = URI.parse(@server_url)
      ws_scheme = uri.scheme == "https" ? "wss" : "ws"
      port = uri.port || (uri.scheme == "https" ? 443 : 80)
      ws_url = "#{ws_scheme}://#{uri.host}:#{port}/ws"

      Log.info { "Connecting to #{ws_url}..." }

      begin
        socket = HTTP::WebSocket.new(URI.parse(ws_url))
        @socket = socket

        setup_socket_handlers(socket)

        # Run the socket in a fiber
        spawn do
          begin
            socket.run
          rescue ex
            Log.error { "WebSocket error: #{ex.message}" }
          end
        end

        # Give the socket time to establish connection
        sleep 0.1.seconds

        @connected = true
        @reconnect_attempts = 0

        # Begin authentication flow
        authenticate

      rescue ex
        Log.error { "Connection failed: #{ex.message}" }
        @on_error.try(&.call("Connection failed: #{ex.message}"))
        handle_reconnect
      end
    end

    private def setup_socket_handlers(socket : HTTP::WebSocket)
      socket.on_binary do |bytes|
        handle_message(bytes)
      end

      socket.on_close do |code|
        Log.info { "Disconnected from server (code: #{code})" }
        @connected = false
        @authenticated = false
        @on_disconnect.try(&.call)

        # Attempt reconnection if still running
        if @running && @auto_reconnect
          handle_reconnect
        end
      end

      socket.on_ping do |message|
        socket.pong(message)
      end
    end

    private def handle_reconnect
      return unless @running && @auto_reconnect

      @reconnect_attempts += 1

      if @reconnect_attempts > @max_reconnect_attempts
        Log.error { "Max reconnection attempts (#{@max_reconnect_attempts}) exceeded. Giving up." }
        @on_error.try(&.call("Max reconnection attempts exceeded"))
        @running = false
        return
      end

      delay = @reconnect_delay * @reconnect_attempts  # Exponential backoff
      Log.info { "Reconnecting in #{delay.total_seconds.to_i} seconds (attempt #{@reconnect_attempts}/#{@max_reconnect_attempts})..." }

      sleep delay
      connect if @running
    end

    private def authenticate
      socket = @socket
      return unless socket

      if key = @api_key
        Log.debug { "Sending authentication with API key" }
        send_message(Protocol::Messages::Auth.new(api_key: key))
      else
        # No auth required - skip to opening tunnel
        Log.debug { "No API key configured, opening tunnel directly" }
        open_tunnel
      end
    end

    private def open_tunnel
      Log.debug { "Requesting tunnel open for local port #{@local_port}" }
      send_message(Protocol::Messages::TunnelOpen.new(
        tunnel_type: "http",
        local_port: @local_port,
        subdomain: @subdomain,
        auth: @auth
      ))
    end

    private def handle_message(bytes : Bytes)
      message = Protocol::Message.from_msgpack(bytes)

      case message
      when Protocol::Messages::AuthOk
        handle_auth_ok(message)

      when Protocol::Messages::AuthError
        handle_auth_error(message)

      when Protocol::Messages::TunnelReady
        handle_tunnel_ready(message)

      when Protocol::Messages::TunnelClose
        handle_tunnel_close(message)

      when Protocol::Messages::RequestStart
        handle_request_start(message)

      when Protocol::Messages::RequestBody
        handle_request_body(message)

      when Protocol::Messages::Ping
        send_message(Protocol::Messages::Pong.new(message.timestamp))
      end

    rescue ex
      Log.error { "Error handling message: #{ex.message}" }
    end

    private def handle_auth_ok(message : Protocol::Messages::AuthOk)
      Log.info { "Authenticated successfully (account: #{message.account_id})" }
      @authenticated = true
      open_tunnel
    end

    private def handle_auth_error(message : Protocol::Messages::AuthError)
      Log.error { "Authentication failed: #{message.error}" }
      @on_error.try(&.call("Authentication failed: #{message.error}"))
      @auto_reconnect = false  # Don't retry with bad credentials
      stop
    end

    private def handle_tunnel_ready(message : Protocol::Messages::TunnelReady)
      @tunnel_id = message.tunnel_id
      @public_url = message.url
      Log.info { "Tunnel ready: #{message.url}" }
      @on_connect.try(&.call(message.url))
    end

    private def handle_tunnel_close(message : Protocol::Messages::TunnelClose)
      reason = message.reason || "No reason provided"
      Log.warn { "Tunnel closed by server: #{reason}" }
      @on_error.try(&.call("Tunnel closed: #{reason}"))

      # Clear tunnel state
      @tunnel_id = nil
      @public_url = nil

      # If tunnel was closed due to an error (like subdomain taken), don't reconnect
      if reason.includes?("not available")
        @auto_reconnect = false
        stop
      end
    end

    private def handle_request_start(message : Protocol::Messages::RequestStart)
      Log.debug { "Request start: #{message.method} #{message.path}" }
      @on_request.try(&.call(message))

      # Store request metadata and initialize body buffer
      @pending_requests[message.request_id] = message
      @request_bodies[message.request_id] = IO::Memory.new
    end

    private def handle_request_body(message : Protocol::Messages::RequestBody)
      body_io = @request_bodies[message.request_id]?
      return unless body_io

      # Write chunk to body buffer
      body_io.write(message.chunk) unless message.chunk.empty?

      if message.final
        # Request body complete - forward to local service
        spawn do
          forward_request(message.request_id)
        end
      end
    end

    private def forward_request(request_id : String)
      start_msg = @pending_requests.delete(request_id)
      body_io = @request_bodies.delete(request_id)

      return unless start_msg && body_io

      body_io.rewind
      body = body_io.size > 0 ? body_io : nil

      Log.debug { "Forwarding request #{request_id}: #{start_msg.method} #{start_msg.path}" }

      start_time = Time.monotonic

      status_code, headers, response_body = @proxy.forward(
        start_msg.method,
        start_msg.path,
        start_msg.headers,
        body
      )

      duration = (Time.monotonic - start_time).total_milliseconds

      Log.debug { "Response from local service: #{status_code} (#{duration.round(2)}ms)" }

      # Send response headers
      send_message(Protocol::Messages::ResponseStart.new(
        request_id: request_id,
        status_code: status_code,
        headers: headers
      ))

      # Stream response body in chunks
      buffer = Bytes.new(8192)
      while (read = response_body.read(buffer)) > 0
        chunk = buffer[0, read].dup
        send_message(Protocol::Messages::ResponseBody.new(
          request_id: request_id,
          chunk: chunk
        ))
      end

      # Signal end of response
      send_message(Protocol::Messages::ResponseEnd.new(request_id: request_id))

    rescue ex
      Log.error { "Error forwarding request #{request_id}: #{ex.message}" }

      # Send error response if we haven't started sending yet
      send_message(Protocol::Messages::ResponseStart.new(
        request_id: request_id,
        status_code: 500,
        headers: {"Content-Type" => "text/plain"}
      ))

      error_bytes = "Internal proxy error: #{ex.message}".to_slice
      send_message(Protocol::Messages::ResponseBody.new(
        request_id: request_id,
        chunk: error_bytes
      ))

      send_message(Protocol::Messages::ResponseEnd.new(request_id: request_id))
    end

    private def send_message(message : Protocol::Message)
      socket = @socket
      return unless socket

      begin
        socket.send(message.to_msgpack)
      rescue ex
        Log.error { "Failed to send message: #{ex.message}" }
      end
    end
  end
end
