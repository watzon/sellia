require "http/server"
require "http/web_socket"
require "log"

module Sellia::Server
  # Tracks a pending WebSocket upgrade request
  class PendingWebSocket
    Log = ::Log.for(self)

    property id : String
    property context : HTTP::Server::Context
    property tunnel_id : String
    property created_at : Time

    @socket : HTTP::WebSocket?
    @closed : Bool = false
    @upgrade_complete : Channel(Bool)
    @on_frame : Proc(UInt8, Bytes, Nil)?
    @on_close : Proc(UInt16?, Nil)?

    def initialize(@id : String, @context : HTTP::Server::Context, @tunnel_id : String)
      @created_at = Time.utc
      @upgrade_complete = Channel(Bool).new(1)
    end

    # Set callback for receiving frames from external client
    def on_frame(&block : UInt8, Bytes ->)
      @on_frame = block
    end

    # Set callback for connection close
    def on_close(&block : UInt16? ->)
      @on_close = block
    end

    # Complete the WebSocket upgrade after client confirms local connection
    def complete_upgrade(response_headers : Hash(String, String))
      return if @closed

      # Set response headers from client (excluding hop-by-hop)
      response_headers.each do |key, value|
        next if hop_by_hop_header?(key)
        @context.response.headers[key] = value
      end

      # Perform WebSocket upgrade
      handler = HTTP::WebSocketHandler.new do |socket, ctx|
        @socket = socket
        setup_handlers(socket)
        @upgrade_complete.send(true)
        # socket.run is called by the handler
      end

      spawn do
        handler.call(@context)
      end
    end

    # Fail the WebSocket upgrade
    def fail_upgrade(status : Int32, message : String)
      return if @closed
      @closed = true
      @context.response.status_code = status
      @context.response.content_type = "text/plain"
      @context.response.print(message)
      @context.response.close
      @upgrade_complete.send(false)
    end

    # Wait for upgrade to complete
    def wait_for_upgrade(timeout : Time::Span = 30.seconds) : Bool
      select
      when result = @upgrade_complete.receive
        result
      when timeout(timeout)
        Log.warn { "WebSocket upgrade timeout for #{@id}" }
        fail_upgrade(504, "WebSocket upgrade timeout")
        false
      end
    end

    # Get the WebSocket once upgrade is complete
    def socket : HTTP::WebSocket?
      @socket
    end

    # Send a frame to the external client
    def send_frame(opcode : UInt8, payload : Bytes)
      socket = @socket
      return unless socket
      return if @closed

      case opcode
      when 0x01_u8 # Text
        socket.send(String.new(payload))
      when 0x02_u8 # Binary
        socket.send(payload)
      when 0x09_u8 # Ping
        socket.ping(String.new(payload))
      when 0x0A_u8 # Pong
        socket.pong(String.new(payload))
      end
    rescue ex
      Log.warn { "WebSocket #{@id} send failed: #{ex.message}" }
    end

    # Close the WebSocket connection
    def close
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
        socket.pong(message)
      end

      socket.on_close do |code|
        @closed = true
        @on_close.try(&.call(code.try(&.to_u16)))
      end
    end

    private def hop_by_hop_header?(key : String) : Bool
      key.downcase.in?(
        "connection",
        "upgrade",
        "sec-websocket-accept",
        "sec-websocket-extensions",
        "transfer-encoding"
      )
    end
  end

  # Thread-safe store for pending WebSocket connections
  class PendingWebSocketStore
    def initialize
      @connections = {} of String => PendingWebSocket
      @mutex = Mutex.new
    end

    def add(ws : PendingWebSocket)
      @mutex.synchronize { @connections[ws.id] = ws }
    end

    def get(id : String) : PendingWebSocket?
      @mutex.synchronize { @connections[id]? }
    end

    def remove(id : String) : PendingWebSocket?
      @mutex.synchronize { @connections.delete(id) }
    end

    def remove_by_tunnel(tunnel_id : String) : Int32
      @mutex.synchronize do
        removed = 0
        @connections.reject! do |_, ws|
          if ws.tunnel_id == tunnel_id
            spawn { ws.close }
            removed += 1
            true
          else
            false
          end
        end
        removed
      end
    end

    def size : Int32
      @mutex.synchronize { @connections.size }
    end

    def cleanup_expired(max_age : Time::Span = 60.seconds)
      @mutex.synchronize do
        now = Time.utc
        @connections.reject! do |_, ws|
          if (now - ws.created_at) > max_age && !ws.socket
            spawn { ws.close }
            true
          else
            false
          end
        end
      end
    end
  end
end
