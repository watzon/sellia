require "socket"
require "log"

module Sellia
  class TunnelAgent
    Log = ::Log.for("TunnelAgent")

    getter port : Int32
    getter client_id : String
    getter max_sockets : Int32

    @server : TCPServer?
    @available_sockets : Array(TCPSocket)
    @waiting_connections : Array(Channel(TCPSocket))
    @waiting_connections : Array(Channel(TCPSocket))
    getter connected_sockets : Int32
    @started : Bool
    @started : Bool
    @closed : Bool

    def initialize(@client_id : String, @max_sockets : Int32 = 10)
      @available_sockets = [] of TCPSocket
      @waiting_connections = [] of Channel(TCPSocket)
      @connected_sockets = 0
      @started = false
      @closed = false
      @port = 0
    end

    def listen
      raise "Already started" if @started
      @started = true

      # Bind to a random port
      server = TCPServer.new("0.0.0.0", 0)
      @port = server.local_address.port
      @server = server

      Log.info { "TunnelAgent[#{@client_id}] listening on port #{@port}" }

      spawn do
        accept_connections(server)
      end

      @port
    end

    def get_socket : TCPSocket
      raise "Closed" if @closed

      # If we have an available socket, return it
      if socket = @available_sockets.shift?
        Log.debug { "TunnelAgent[#{@client_id}] reusing socket" }
        return socket
      end

      # If no socket is available, wait for one
      Log.debug { "TunnelAgent[#{@client_id}] waiting for socket" }
      channel = Channel(TCPSocket).new
      @waiting_connections << channel

      # TODO: Add timeout
      socket = channel.receive
      socket
    end

    def close
      return if @closed
      @closed = true
      @server.try &.close
      @available_sockets.each &.close
      @available_sockets.clear
      # TODO: Notify waiting connections
    end

    private def accept_connections(server : TCPServer)
      while !server.closed?
        begin
          if socket = server.accept?
            handle_connection(socket)
          else
            break
          end
        rescue ex
          Log.error(exception: ex) { "Error accepting connection" }
          break
        end
      end
    end

    private def handle_connection(socket : TCPSocket)
      if @connected_sockets >= @max_sockets
        Log.warn { "TunnelAgent[#{@client_id}] max sockets reached, closing connection" }
        socket.close
        return
      end

      @connected_sockets += 1
      Log.debug { "TunnelAgent[#{@client_id}] new connection from #{socket.remote_address}" }

      socket.read_buffering = false
      socket.sync = true

      # Handle socket closure
      # We can't easily detect closure without reading, but we can handle errors when writing

      # If someone is waiting for a socket, give it to them immediately
      if channel = @waiting_connections.shift?
        channel.send(socket)
      else
        @available_sockets << socket
      end
    end
  end
end
