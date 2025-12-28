require "http/web_socket"
require "uri"
require "log"

module Sellia::CLI
  # Manages a WebSocket connection to a local service for passthrough
  class WebSocketProxy
    Log = ::Log.for(self)

    property request_id : String
    property host : String
    property port : Int32

    @socket : HTTP::WebSocket?
    @on_frame : Proc(UInt8, Bytes, Nil)?
    @on_close : Proc(UInt16?, String?, Nil)?
    @closed : Bool = false
    @mutex : Mutex = Mutex.new

    def initialize(@request_id : String, @host : String, @port : Int32)
    end

    # Set callback for receiving frames from local WebSocket
    def on_frame(&block : UInt8, Bytes ->)
      @on_frame = block
    end

    # Set callback for connection close
    def on_close(&block : UInt16?, String? ->)
      @on_close = block
    end

    # Attempt WebSocket upgrade to local service
    # Returns response headers on success, nil on failure
    def connect(path : String, headers : Hash(String, String)) : Hash(String, String)?
      uri = URI.new(scheme: "ws", host: @host, port: @port, path: path)

      # Build HTTP headers for upgrade, preserving WebSocket headers
      http_headers = HTTP::Headers.new
      headers.each do |key, value|
        key_lower = key.downcase
        # Keep WebSocket-specific headers, Host, and Origin
        if key_lower.starts_with?("sec-websocket-") ||
           key_lower == "host" ||
           key_lower == "origin"
          http_headers[key] = value
        end
      end

      begin
        socket = HTTP::WebSocket.new(uri, headers: http_headers)
        @socket = socket

        setup_handlers(socket)

        # Run socket in background fiber
        spawn do
          begin
            socket.run
          rescue ex
            Log.debug { "WebSocket #{@request_id} closed: #{ex.message}" }
          end
          handle_close(nil, nil) unless @closed
        end

        Log.debug { "WebSocket #{@request_id} connected to #{@host}:#{@port}#{path}" }

        # Return synthetic response headers (Crystal WS doesn't expose response headers)
        {"Connection" => "Upgrade", "Upgrade" => "websocket"}
      rescue ex : Socket::ConnectError
        Log.warn { "WebSocket connect failed for #{@request_id}: #{ex.message}" }
        nil
      rescue ex
        Log.warn { "WebSocket upgrade failed for #{@request_id}: #{ex.message}" }
        nil
      end
    end

    # Send a frame to the local WebSocket
    def send_frame(opcode : UInt8, payload : Bytes)
      socket = @socket
      return unless socket
      return if @closed

      @mutex.synchronize do
        case opcode
        when 0x01_u8 # Text
          socket.send(String.new(payload))
        when 0x02_u8 # Binary
          socket.send(payload)
        when 0x08_u8 # Close
          close
        when 0x09_u8 # Ping
          socket.ping(String.new(payload))
        when 0x0A_u8 # Pong
          socket.pong(String.new(payload))
        end
      end
    rescue ex
      Log.warn { "WebSocket #{@request_id} send failed: #{ex.message}" }
    end

    # Close the WebSocket connection
    def close(code : UInt16? = nil, reason : String? = nil)
      return if @closed
      @closed = true
      @socket.try(&.close)
    end

    def closed? : Bool
      @closed
    end

    private def setup_handlers(socket : HTTP::WebSocket)
      socket.on_binary do |bytes|
        @on_frame.try(&.call(0x02_u8, bytes))
      end

      socket.on_message do |text|
        @on_frame.try(&.call(0x01_u8, text.to_slice))
      end

      socket.on_ping do |message|
        # Auto-respond with pong
        socket.pong(message)
      end

      socket.on_close do |code|
        handle_close(code.try(&.to_u16), nil)
      end
    end

    private def handle_close(code : UInt16?, reason : String?)
      return if @closed
      @closed = true
      @on_close.try(&.call(code, reason))
    end
  end
end
