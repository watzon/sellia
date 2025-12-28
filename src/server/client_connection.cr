require "http/web_socket"
require "log"
require "../core/protocol"

module Sellia::Server
  class ClientConnection
    Log = ::Log.for("sellia.server.connection")

    property id : String
    property api_key : String?
    property socket : HTTP::WebSocket
    property authenticated : Bool
    property created_at : Time
    property last_activity : Time

    @message_handler : (Protocol::Message -> Nil)?
    @close_handler : (-> Nil)?
    @closed : Bool = false

    def initialize(@socket : HTTP::WebSocket, @id : String = Random::Secure.hex(16))
      @authenticated = false
      @created_at = Time.utc
      @last_activity = Time.utc

      setup_handlers
    end

    private def setup_handlers
      @socket.on_binary do |bytes|
        @last_activity = Time.utc
        begin
          message = Protocol::Message.from_msgpack(bytes)
          @message_handler.try(&.call(message))
        rescue ex : MessagePack::Error | MessagePack::TypeCastError
          Log.warn { "Failed to parse message from #{@id}: #{ex.message}" }
        rescue ex
          # Catch ALL exceptions from message handlers to prevent crashing socket.run
          # This is critical - unhandled exceptions here will close the WebSocket
          Log.warn { "Error handling message from #{@id}: #{ex.class.name} - #{ex.message}" }
          Log.debug { ex.backtrace.first(5).join("\n") } if ex.backtrace
        end
      end

      @socket.on_close do
        @closed = true
        @close_handler.try(&.call)
      end
    end

    def on_message(&handler : Protocol::Message -> Nil)
      @message_handler = handler
    end

    def on_close(&handler : -> Nil)
      @close_handler = handler
    end

    def send(message : Protocol::Message) : Bool
      return false if @closed
      @socket.send(message.to_msgpack)
      true
    rescue ex : IO::Error
      Log.debug { "Send failed for #{@id}: #{ex.message}" }
      false
    end

    def close(reason : String? = nil)
      return if @closed
      @closed = true
      @socket.close(message: reason || "Connection closed")
    rescue
      # Socket may already be closed
    end

    def closed? : Bool
      @closed
    end

    # Check if connection is stale (no activity within timeout)
    def stale?(timeout : Time::Span = 60.seconds) : Bool
      Time.utc - @last_activity > timeout
    end

    # Send a ping message
    def ping
      return if @closed
      send(Protocol::Messages::Ping.new(Time.utc.to_unix_ms))
    end

    def run
      @socket.run
    end
  end
end
