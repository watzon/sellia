require "http/web_socket"
require "../core/protocol"

module Sellia::Server
  class ClientConnection
    property id : String
    property api_key : String?
    property socket : HTTP::WebSocket
    property authenticated : Bool
    property created_at : Time

    @message_handler : (Protocol::Message -> Nil)?
    @close_handler : (-> Nil)?

    def initialize(@socket : HTTP::WebSocket, @id : String = Random::Secure.hex(16))
      @authenticated = false
      @created_at = Time.utc

      setup_handlers
    end

    private def setup_handlers
      @socket.on_binary do |bytes|
        begin
          message = Protocol::Message.from_msgpack(bytes)
          @message_handler.try(&.call(message))
        rescue ex
          # Log parse error but don't crash
          puts "Failed to parse message: #{ex.message}"
        end
      end

      @socket.on_close do
        @close_handler.try(&.call)
      end
    end

    def on_message(&handler : Protocol::Message -> Nil)
      @message_handler = handler
    end

    def on_close(&handler : -> Nil)
      @close_handler = handler
    end

    def send(message : Protocol::Message)
      @socket.send(message.to_msgpack)
    end

    def close(reason : String? = nil)
      @socket.close(reason || "Connection closed")
    rescue
      # Socket may already be closed
    end

    def run
      @socket.run
    end
  end
end
