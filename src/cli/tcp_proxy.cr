require "socket"
require "log"
require "io"

module Sellia::CLI
  # Manages a TCP connection to a local service
  class TcpProxy
    Log = ::Log.for(self)

    property connection_id : String
    property host : String
    property port : Int32

    @socket : TCPSocket?
    @running : Bool = false
    @read_fiber : Fiber?
    @write_mutex : Mutex = Mutex.new
    @on_data : Proc(Bytes, Nil)?
    @on_close : Proc(String?, Nil)?

    def initialize(@connection_id : String, @host : String, @port : Int32)
    end

    # Set callback for receiving data from local service
    def on_data(&block : Bytes ->)
      @on_data = block
    end

    # Set callback for connection close
    def on_close(&block : String? ->)
      @on_close = block
    end

    # Connect to local TCP service
    def connect : Bool
      begin
        @socket = TCPSocket.new(@host, @port)
        @running = true

        # Start read loop
        @read_fiber = spawn read_loop

        Log.debug { "TCP #{@connection_id} connected to #{@host}:#{@port}" }
        true
      rescue ex : Socket::Error | IO::Error
        Log.warn { "TCP #{@connection_id} connect failed: #{ex.message}" }
        false
      end
    end

    # Send data to local service
    def send_data(data : Bytes)
      socket = @socket
      return unless socket
      return unless @running

      @write_mutex.synchronize do
        begin
          socket.write(data)
          socket.flush
        rescue ex : IO::Error
          Log.debug { "TCP #{@connection_id} write failed: #{ex.message}" }
          close
        end
      end
    end

    # Close the connection
    def close(reason : String? = nil)
      return unless @running
      @running = false

      @socket.try do |sock|
        begin
          sock.close
        rescue
        end
      end
      @socket = nil

      @on_close.try(&.call(reason))
    end

    def closed? : Bool
      !@running
    end

    private def read_loop
      socket = @socket
      return unless socket

      buffer = Bytes.new(8192)

      while @running
        begin
          size = socket.read(buffer)
          if size == 0
            # Connection closed by remote
            break
          end

          # Forward data to tunnel
          data = buffer[0, size].dup
          @on_data.try(&.call(data))
        rescue ex : IO::Error
          Log.debug { "TCP #{@connection_id} read error: #{ex.message}" }
          break
        end
      end

      close("Connection closed")
    end
  end
end
