require "socket"
require "log"

module Sellia
  class TunnelCluster
    Log = ::Log.for("TunnelCluster")

    def initialize(@remote_host : String, @remote_port : Int32, @local_port : Int32, @max_conn : Int32 = 10, @local_host : String = "localhost")
    end

    def start
      Log.info { "Starting tunnel cluster connecting to #{@remote_host}:#{@remote_port}" }

      @max_conn.times do
        spawn do
          loop do
            handle_connection
            sleep 1.seconds # Backoff on error/close
          end
        end
      end

      # Keep main fiber alive
      sleep
    end

    private def handle_connection
      begin
        remote = TCPSocket.new(@remote_host, @remote_port)
        remote.sync = true
        Log.debug { "Connected to tunnel server" }

        # Read initial chunk to detect activity and rewrite headers
        buffer = Bytes.new(4096)
        bytes_read = remote.read(buffer)

        if bytes_read == 0
          Log.debug { "Remote closed connection" }
          remote.close
          return
        end

        # We got data! Connect to local
        Log.debug { "Received request, forwarding to local" }
        local = TCPSocket.new("localhost", @local_port)
        local.sync = true

        # Rewrite Host header if needed
        data = String.new(buffer[0, bytes_read])

        # Regex to find Host header: \r\nHost: <value>\r\n
        # We replace it with Host: <local_host>
        # Note: This is a simple replacement on the first chunk.
        if @local_host
          # Rewrite Host header. Matches Host: at start of line (after \n or start of string)
          data = data.sub(/((?:^|\n)[Hh]ost: )\S+/, "\\1#{@local_host}")
        end

        local.write(data.to_slice)

        # Pipe the rest
        # We need bidirectional piping

        done = Channel(Nil).new

        spawn do
          begin
            IO.copy(remote, local)
          rescue ex
            Log.debug { "Error piping remote -> local: #{ex.message}" }
          ensure
            local.close_write rescue nil
            done.send(nil)
          end
        end

        spawn do
          begin
            IO.copy(local, remote)
          rescue ex
            Log.debug { "Error piping local -> remote: #{ex.message}" }
          ensure
            remote.close_write rescue nil
            done.send(nil)
          end
        end

        # Wait for both directions to finish
        2.times { done.receive }
      rescue ex
        Log.error { "Tunnel error: #{ex.message}" }
      ensure
        remote.try &.close rescue nil
        local.try &.close rescue nil
      end
    end
  end
end
