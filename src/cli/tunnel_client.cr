require "http/web_socket"
require "uri"
require "log"
require "../core/protocol"
require "./local_proxy"
require "./websocket_proxy"
require "./config"
require "./request_store"
require "./router"

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

    # Request store for inspector (optional)
    property request_store : RequestStore?

    @socket : HTTP::WebSocket?
    @proxy : LocalProxy
    @router : Router
    @running : Bool = false
    @reconnect_attempts : Int32 = 0
    @send_mutex : Mutex = Mutex.new

    # Storage for in-flight requests
    @pending_requests : Hash(String, Protocol::Messages::RequestStart) = {} of String => Protocol::Messages::RequestStart
    @request_bodies : Hash(String, IO::Memory) = {} of String => IO::Memory
    @request_start_times : Hash(String, Time::Span) = {} of String => Time::Span

    # Active WebSocket connections for passthrough
    @active_websockets : Hash(String, WebSocketProxy) = {} of String => WebSocketProxy

    # Callbacks
    @on_connect : (String ->)?
    @on_request : (Protocol::Messages::RequestStart ->)?
    @on_websocket : (String, String ->)? # (path, request_id)
    @on_disconnect : (->)?
    @on_error : (String ->)?

    def initialize(
      @server_url : String,
      @local_port : Int32,
      @api_key : String? = nil,
      @local_host : String = "localhost",
      @subdomain : String? = nil,
      @auth : String? = nil,
      @request_store : RequestStore? = nil,
      routes : Array(RouteConfig) = [] of RouteConfig,
    )
      @proxy = LocalProxy.new(@local_host, @local_port)
      @router = Router.new(routes, @local_host, @local_port > 0 ? @local_port : nil)
    end

    # Get the configured routes for display
    def routes : Array(RouteConfig)
      @router.routes
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

    # Set callback for WebSocket connections
    def on_websocket(&block : String, String ->)
      @on_websocket = block
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

      # Clear in-flight requests to prevent memory leaks
      @pending_requests.clear
      @request_bodies.clear
      @request_start_times.clear

      # Close all active WebSocket connections
      @active_websockets.each_value(&.close)
      @active_websockets.clear
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
          rescue Channel::ClosedError
            # Log channel closed during shutdown - ignore
          rescue ex
            # Only log if we're still running - avoid Channel::ClosedError during shutdown
            begin
              Log.error { "WebSocket error: #{ex.message}" } if @running
            rescue Channel::ClosedError
              # Ignore log channel closed during shutdown
            end
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
        begin
          Log.info { "Disconnected from server (code: #{code})" } if @running
        rescue Channel::ClosedError
          # Ignore log channel closed during shutdown
        end
        @connected = false
        @authenticated = false

        # Clear in-flight requests to prevent memory leaks
        @pending_requests.clear
        @request_bodies.clear

        # Close all active WebSocket connections
        @active_websockets.each_value(&.close)
        @active_websockets.clear

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

      delay = @reconnect_delay * @reconnect_attempts # Linear backoff
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
      when Protocol::Messages::WebSocketUpgrade
        handle_websocket_upgrade(message)
      when Protocol::Messages::WebSocketFrame
        handle_websocket_frame(message)
      when Protocol::Messages::WebSocketClose
        handle_websocket_close(message)
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
      @auto_reconnect = false # Don't retry with bad credentials
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

      # Store request metadata, initialize body buffer, and record start time
      @pending_requests[message.request_id] = message
      @request_bodies[message.request_id] = IO::Memory.new
      @request_start_times[message.request_id] = Time.monotonic
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
      start_time = @request_start_times.delete(request_id) || Time.monotonic

      return unless start_msg && body_io

      body_io.rewind
      request_body_content = body_io.size > 0 ? body_io.gets_to_end : nil
      body_io.rewind
      body = body_io.size > 0 ? body_io : nil

      # Route the request
      match_result = @router.match(start_msg.path)

      matched_route : String? = nil
      matched_target : String? = nil
      target_host = @local_host
      target_port = @local_port

      if match = match_result
        matched_route = match.pattern
        matched_target = "#{match.target.host}:#{match.target.port}"
        target_host = match.target.host
        target_port = match.target.port
        Log.debug { "Routed #{start_msg.path} to #{matched_target} via #{matched_route}" }
      else
        # No route matched and no fallback
        Log.warn { "No route matched for #{start_msg.path}" }
        send_message(Protocol::Messages::ResponseStart.new(
          request_id: request_id,
          status_code: 502,
          headers: {"Content-Type" => ["text/plain"]}
        ))
        error_msg = "No route matched path: #{start_msg.path}"
        send_message(Protocol::Messages::ResponseBody.new(
          request_id: request_id,
          chunk: error_msg.to_slice
        ))
        send_message(Protocol::Messages::ResponseEnd.new(request_id: request_id))
        return
      end

      Log.debug { "Forwarding request #{request_id}: #{start_msg.method} #{start_msg.path}" }

      status_code, headers, response_body = @proxy.forward(
        start_msg.method,
        start_msg.path,
        start_msg.headers,
        body,
        target_host,
        target_port
      )

      duration = (Time.monotonic - start_time).total_milliseconds

      Log.debug { "Response from local service: #{status_code} (#{duration.round(2)}ms)" }

      # Send response headers
      send_message(Protocol::Messages::ResponseStart.new(
        request_id: request_id,
        status_code: status_code,
        headers: headers
      ))

      # Stream response body in chunks and capture for inspector
      response_body_chunks = IO::Memory.new
      buffer = Bytes.new(8192)
      while (read = response_body.read(buffer)) > 0
        chunk = buffer[0, read].dup
        response_body_chunks.write(chunk)
        send_message(Protocol::Messages::ResponseBody.new(
          request_id: request_id,
          chunk: chunk
        ))
      end

      # Signal end of response
      send_message(Protocol::Messages::ResponseEnd.new(request_id: request_id))

      # Store request in the inspector if request_store is configured
      if store = @request_store
        response_body_chunks.rewind
        response_body_content = response_body_chunks.gets_to_end

        # Limit body size for storage (max 100KB for display)
        max_body_size = 100_000
        if request_body_content && request_body_content.size > max_body_size
          request_body_content = request_body_content[0, max_body_size] + "\n... (truncated)"
        end
        if response_body_content.size > max_body_size
          response_body_content = response_body_content[0, max_body_size] + "\n... (truncated)"
        end

        stored_request = StoredRequest.new(
          id: request_id,
          method: start_msg.method,
          path: start_msg.path,
          status_code: status_code,
          duration: duration.to_i64,
          timestamp: Time.utc,
          request_headers: start_msg.headers,
          request_body: request_body_content,
          response_headers: headers,
          response_body: response_body_content.empty? ? nil : response_body_content,
          matched_route: matched_route,
          matched_target: matched_target
        )
        store.add(stored_request)
      end
    rescue ex
      Log.error { "Error forwarding request #{request_id}: #{ex.message}" }

      error_duration = if actual_start = start_time
                         (Time.monotonic - actual_start).total_milliseconds.to_i64
                       else
                         0_i64
                       end

      # Send error response if we haven't started sending yet
      send_message(Protocol::Messages::ResponseStart.new(
        request_id: request_id,
        status_code: 500,
        headers: {"Content-Type" => ["text/plain"]}
      ))

      error_bytes = "Internal proxy error: #{ex.message}".to_slice
      send_message(Protocol::Messages::ResponseBody.new(
        request_id: request_id,
        chunk: error_bytes
      ))

      send_message(Protocol::Messages::ResponseEnd.new(request_id: request_id))

      # Store error request in inspector if configured
      if store = @request_store
        stored_request = StoredRequest.new(
          id: request_id,
          method: start_msg.try(&.method) || "UNKNOWN",
          path: start_msg.try(&.path) || "/",
          status_code: 500,
          duration: error_duration,
          timestamp: Time.utc,
          request_headers: start_msg.try(&.headers) || {} of String => Array(String),
          request_body: nil,
          response_headers: {"Content-Type" => ["text/plain"]},
          response_body: "Internal proxy error: #{ex.message}",
          matched_route: matched_route,
          matched_target: matched_target
        )
        store.add(stored_request)
      end
    end

    private def handle_websocket_upgrade(message : Protocol::Messages::WebSocketUpgrade)
      Log.debug { "WebSocket upgrade request: #{message.path}" }

      # Route the WebSocket request
      match_result = @router.match(message.path)

      target_host = @local_host
      target_port = @local_port

      if match = match_result
        target_host = match.target.host
        target_port = match.target.port
        Log.debug { "WebSocket routed #{message.path} to #{target_host}:#{target_port} via #{match.pattern}" }
      else
        # No route matched
        Log.warn { "WebSocket no route matched for #{message.path}" }
        send_message(Protocol::Messages::WebSocketUpgradeError.new(
          request_id: message.request_id,
          status_code: 502,
          message: "No route matched path: #{message.path}"
        ))
        return
      end

      ws_proxy = WebSocketProxy.new(message.request_id, target_host, target_port)

      # Set up frame forwarding to server
      ws_proxy.on_frame do |opcode, payload|
        send_message(Protocol::Messages::WebSocketFrame.new(
          request_id: message.request_id,
          opcode: opcode,
          payload: payload
        ))
      end

      ws_proxy.on_close do |code, reason|
        send_message(Protocol::Messages::WebSocketClose.new(
          request_id: message.request_id,
          code: code,
          reason: reason
        ))
        @active_websockets.delete(message.request_id)
      end

      # Attempt connection to local service
      Log.debug { "WebSocket attempting connection to local service: #{target_host}:#{target_port}#{message.path}" }
      response_headers = ws_proxy.connect(message.path, message.headers)

      if response_headers
        Log.debug { "WebSocket connected successfully, sending UpgradeOk for #{message.request_id}" }
        @active_websockets[message.request_id] = ws_proxy
        send_message(Protocol::Messages::WebSocketUpgradeOk.new(
          request_id: message.request_id,
          headers: response_headers
        ))
        # Notify callback for logging
        @on_websocket.try(&.call(message.path, message.request_id))
      else
        Log.warn { "WebSocket connection failed for #{message.request_id}" }
        send_message(Protocol::Messages::WebSocketUpgradeError.new(
          request_id: message.request_id,
          status_code: 502,
          message: "Failed to connect to local WebSocket service"
        ))
      end
    rescue ex
      Log.error { "WebSocket upgrade error for #{message.request_id}: #{ex.class}: #{ex.message}" }
      Log.error { ex.backtrace.join("\n") }
      send_message(Protocol::Messages::WebSocketUpgradeError.new(
        request_id: message.request_id,
        status_code: 500,
        message: "Internal error: #{ex.message}"
      ))
    end

    private def handle_websocket_frame(message : Protocol::Messages::WebSocketFrame)
      if ws_proxy = @active_websockets[message.request_id]?
        ws_proxy.send_frame(message.opcode, message.payload)
      end
    end

    private def handle_websocket_close(message : Protocol::Messages::WebSocketClose)
      if ws_proxy = @active_websockets.delete(message.request_id)
        ws_proxy.close(message.code, message.reason)
      end
    end

    private def send_message(message : Protocol::Message)
      socket = @socket
      return unless socket
      return unless @running # Don't send after shutdown initiated

      # Mutex protects against concurrent WebSocket writes from multiple fibers
      # Without this, parallel request handlers can interleave frames and corrupt the stream
      @send_mutex.synchronize do
        socket.send(message.to_msgpack)
      end
    rescue Channel::ClosedError
      # Log channel closed during shutdown - ignore
    rescue ex
      begin
        Log.error { "Failed to send message: #{ex.message}" } if @running
      rescue Channel::ClosedError
        # Ignore log channel closed during shutdown
      end
    end
  end
end
