require "http/server"
require "http/web_socket"
require "openssl"
require "base64"
require "log"

module Sellia::Server
  # Tracks a pending WebSocket upgrade request
  #
  # The actual WebSocket handshake and frame reading is handled by
  # HTTPIngress using response.upgrade. This class just tracks state
  # and provides signaling between the HTTP handler and WSGateway.
  class PendingWebSocket
    Log = ::Log.for(self)

    property id : String
    property context : HTTP::Server::Context
    property tunnel_id : String
    property created_at : Time
    property ws_protocol : HTTP::WebSocket::Protocol? # Set after upgrade is complete

    @closed : Bool = false
    @upgrade_succeeded : Bool = false
    @upgrade_complete : Channel(Bool)
    @connection_closed : Channel(Nil)
    @frame_callback : Proc(UInt8, Bytes, Nil)?
    @close_callback : Proc(UInt16?, Nil)?
    @ws_key : String? # Store the WebSocket key from original request

    WEBSOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    def initialize(@id : String, @context : HTTP::Server::Context, @tunnel_id : String)
      @created_at = Time.utc
      @upgrade_complete = Channel(Bool).new(1)
      @connection_closed = Channel(Nil).new(1)

      # Extract and store the WebSocket key from the original request
      @ws_key = @context.request.headers["Sec-WebSocket-Key"]?
    end

    # Set callback for receiving frames from external client
    def on_frame(&block : UInt8, Bytes ->)
      @frame_callback = block
    end

    # Set callback for connection close
    def on_close(&block : UInt16? ->)
      @close_callback = block
    end

    # Invoke the frame callback (called by frame loop)
    def handle_frame(opcode : UInt8, payload : Bytes)
      @frame_callback.try(&.call(opcode, payload))
    end

    # Invoke the close callback (called by frame loop)
    def handle_close(code : UInt16?)
      @close_callback.try(&.call(code))
    end

    # Signal that the CLI has confirmed the local WebSocket connection
    # This is called by WSGateway when it receives WebSocketUpgradeOk
    def signal_upgrade_confirmed
      return if @upgrade_succeeded
      Log.info { "WebSocket #{@id}: CLI confirmed local connection" }
      @upgrade_succeeded = true
      @upgrade_complete.send(true)
    end

    # Fail the WebSocket upgrade
    def fail_upgrade(status : Int32, message : String)
      return if @closed
      return if @upgrade_succeeded # Don't fail if upgrade already succeeded

      @closed = true

      # Only try to write error response if headers haven't been sent
      begin
        @context.response.status_code = status
        @context.response.content_type = "text/plain"
        @context.response.print(message)
        @context.response.close
      rescue ex : IO::Error
        # Headers already sent (upgrade may have succeeded), just log and continue
        Log.debug { "WebSocket #{@id} fail_upgrade skipped - connection already upgraded" }
      end

      # Signal failure (may not be received if upgrade already succeeded)
      begin
        @upgrade_complete.send(false)
      rescue Channel::ClosedError
        # Channel already closed, ignore
      end
    end

    # Wait for upgrade to complete
    def wait_for_upgrade(timeout : Time::Span = 30.seconds) : Bool
      select
      when result = @upgrade_complete.receive
        result
      when timeout(timeout)
        # Check if upgrade already succeeded (race condition)
        if @upgrade_succeeded
          Log.debug { "WebSocket upgrade #{@id} succeeded (timeout fired late)" }
          return true
        end

        # If upgrade hasn't succeeded, signal failure
        Log.warn { "WebSocket upgrade timeout for #{@id}" }
        @upgrade_complete.send(false)
        false
      end
    end

    # Signal that the connection has closed
    # Called by the frame loop when the WebSocket connection ends
    def signal_closed
      @closed = true
      @connection_closed.send(nil)
    end

    # Wait for the WebSocket connection to close
    # This keeps the HTTP handler alive while the WebSocket is active
    # NOTE: This is no longer used since response.upgrade keeps the handler alive
    def wait_for_close
      @connection_closed.receive
    end

    # Send a frame to the external client (from CLI)
    def send_frame(opcode : UInt8, payload : Bytes)
      protocol = @ws_protocol
      return unless protocol
      return if @closed

      Log.debug { "WebSocket #{@id}: sending frame opcode=#{opcode}, size=#{payload.size}" }

      begin
        case opcode
        when 0x01_u8 # Text
          protocol.send(String.new(payload))
        when 0x02_u8 # Binary
          protocol.send(payload)
        when 0x08_u8 # Close
          protocol.close
        when 0x09_u8 # Ping
          protocol.ping(payload.empty? ? nil : String.new(payload))
        when 0x0A_u8 # Pong
          protocol.pong(payload.empty? ? nil : String.new(payload))
        else
          Log.warn { "WebSocket #{@id}: unknown opcode #{opcode}" }
        end
      rescue ex
        Log.warn { "WebSocket #{@id} send failed: #{ex.message}" }
      end
    end

    # Close the WebSocket connection
    def close
      return if @closed
      @closed = true
      @ws_protocol.try(&.close)
      @connection_closed.send(nil)
    end

    def closed? : Bool
      @closed
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
          if (now - ws.created_at) > max_age && !ws.closed?
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
