require "socket"
require "log"

module Sellia
  class TunnelCluster
    Log = ::Log.for("TunnelCluster")

    @stopped : Bool = false

    def initialize(@remote_host : String, @remote_port : Int32, @local_port : Int32, @max_conn : Int32 = 10, @local_host : String = "localhost")
    end

    def start
      Log.info { "Starting tunnel cluster connecting to #{@remote_host}:#{@remote_port}" }

      @max_conn.times do
        spawn do
          loop do
            break if @stopped
            handle_connection
            sleep 1.seconds # Backoff on error/close
          end
        end
      end

      # Keep main fiber alive
      sleep
    end

    private def handle_connection
      remote : TCPSocket? = nil
      local : TCPSocket? = nil

      begin
        # Connection to localtunnel server
        remote = TCPSocket.new(@remote_host, @remote_port)
        remote.sync = true
        remote.keepalive = true
        remote.tcp_keepalive_idle = 60
        remote.tcp_keepalive_interval = 10
        remote.tcp_keepalive_count = 3

        Log.debug { "Connected to tunnel server at #{@remote_host}:#{@remote_port}" }

        # Wait for the first data from remote (this means we have a request to proxy)
        initial_buffer = Bytes.new(4096)
        bytes_read = 0

        # Read until we have headers or buffer is full
        while bytes_read < 4096
          chunk_size = remote.read(initial_buffer[bytes_read...4096])
          break if chunk_size == 0
          bytes_read += chunk_size

          # Check if we have end of headers
          # We can check the string representation so far
          temp_str = String.new(initial_buffer[0, bytes_read])
          break if temp_str.includes?("\r\n\r\n")
        end

        if bytes_read == 0
          Log.debug { "Remote closed connection immediately" }
          return
        end

        # We got data! This is an HTTP request. Now connect to local server.
        Log.debug { "Received #{bytes_read} bytes, connecting to local server" }
        local = TCPSocket.new("localhost", @local_port)
        local.sync = true

        # Rewrite Host header if needed
        request_data = String.new(initial_buffer[0, bytes_read])

        if @local_host
          # Rewrite Host header - match "\r\nHost: value" or "Host: value" at start
          request_data = request_data.sub(/(\r\n[Hh]ost: )\S+/, "\\1#{@local_host}")
          Log.debug { "Rewrote Host header to: #{@local_host}" }
        end

        # Send the (possibly modified) request to local server
        local.write(request_data.to_slice)

        # Now set up bidirectional piping
        done = Channel(Nil).new(2)

        # Pipe remote -> local
        spawn do
          begin
            IO.copy(remote.not_nil!, local.not_nil!)
          rescue ex
            Log.debug { "Remote->Local pipe closed: #{ex.message}" }
          ensure
            local.try(&.close_write) rescue nil
            done.send(nil)
          end
        end

        # Pipe local -> remote
        spawn do
          begin
            IO.copy(local.not_nil!, remote.not_nil!)
          rescue ex
            Log.debug { "Local->Remote pipe closed: #{ex.message}" }
          ensure
            remote.try(&.close_write) rescue nil
            done.send(nil)
          end
        end

        # Wait for both directions to complete
        2.times { done.receive }
        Log.debug { "Tunnel connection closed cleanly" }
      rescue ex : Socket::ConnectError
        Log.error { "Tunnel error: #{ex.message}" }
      rescue ex
        Log.error { "Tunnel error: #{ex.message}" }
      ensure
        remote.try(&.close) rescue nil
        local.try(&.close) rescue nil
      end
    end

    def stop
      @stopped = true
    end
  end
end
