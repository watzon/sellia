require "mutex"
require "./client_connection"

module Sellia::Server
  class ConnectionManager
    def initialize
      @connections = {} of String => ClientConnection
      @by_api_key = {} of String => String # api_key -> client_id
      @mutex = Mutex.new
    end

    def register(api_key : String, connection : ClientConnection? = nil) : String
      @mutex.synchronize do
        client_id = connection.try(&.id) || Random::Secure.hex(16)

        if connection
          @connections[client_id] = connection
          connection.authenticated = true
          connection.api_key = api_key
        end

        @by_api_key[api_key] = client_id
        client_id
      end
    end

    def add_connection(connection : ClientConnection) : Nil
      @mutex.synchronize do
        @connections[connection.id] = connection
      end
    end

    def unregister(client_id : String) : ClientConnection?
      @mutex.synchronize do
        if conn = @connections.delete(client_id)
          @by_api_key.delete(conn.api_key) if conn.api_key
          conn
        end
      end
    end

    def find(client_id : String) : ClientConnection?
      @mutex.synchronize { @connections[client_id]? }
    end

    def find_by_api_key(api_key : String) : ClientConnection?
      @mutex.synchronize do
        if client_id = @by_api_key[api_key]?
          @connections[client_id]?
        end
      end
    end

    def authenticated?(api_key : String) : Bool
      @mutex.synchronize { @by_api_key.has_key?(api_key) }
    end

    def size : Int32
      @mutex.synchronize { @connections.size }
    end

    def broadcast(message : Protocol::Message)
      @mutex.synchronize do
        @connections.each_value do |conn|
          conn.send(message) if conn.authenticated
        end
      end
    end
  end
end
