require "socket"
require "log"
require "mutex"

module Sellia::Server
  # Tracks a pending TCP connection while waiting for client to establish local connection
  class PendingTcp
    Log = ::Log.for(self)

    property id : String
    property tunnel_id : String
    property remote_addr : String
    property client_socket : TCPSocket
    property created_at : Time

    @closed : Bool = false
    @upgrade_complete : Channel(Bool)
    @tcp_proxy : TcpProxy?
    @mutex : Mutex

    def initialize(@id : String, @tunnel_id : String, @remote_addr : String, @client_socket : TCPSocket)
      @created_at = Time.utc
      @upgrade_complete = Channel(Bool).new(1)
      @mutex = Mutex.new
    end

    # Signal that the CLI has confirmed the local TCP connection
    def signal_connected(proxy : TcpProxy)
      return if @closed
      Log.debug { "TCP #{@id}: CLI confirmed local connection" }
      @mutex.synchronize { @tcp_proxy = proxy }
      @upgrade_complete.send(true)
    end

    # Signal that the CLI failed to connect locally
    def signal_failed(message : String)
      return if @closed
      @closed = true
      @upgrade_complete.send(false)
      begin
        @client_socket.close
      rescue
      end
    end

    # Wait for connection to be established
    def wait_for_connection(timeout : Time::Span = 30.seconds) : Bool
      select
      when result = @upgrade_complete.receive
        result
      when timeout(timeout)
        Log.warn { "TCP connection timeout for #{@id}" }
        @upgrade_complete.send(false)
        false
      end
    end

    # Send data to the external client
    def send_data(data : Bytes)
      proxy = @tcp_proxy
      return unless proxy
      return if @closed

      begin
        @client_socket.write(data)
        @client_socket.flush
      rescue ex : IO::Error
        Log.debug { "TCP #{@id} write failed: #{ex.message}" }
        close
      end
    end

    # Close the connection
    def close(reason : String? = nil)
      return if @closed
      @closed = true
      @tcp_proxy.try(&.close)
      begin
        @client_socket.close
      rescue
      end
    end

    def closed? : Bool
      @closed
    end

    def tcp_proxy : TcpProxy?
      @tcp_proxy
    end
  end

  # Server-side TCP proxy that manages bidirectional data flow
  # from external client to CLI
  class TcpProxy
    Log = ::Log.for(self)

    property connection_id : String
    property tunnel_id : String

    @pending_tcp : PendingTcp
    @running : Bool = true
    @read_fiber : Fiber?

    def initialize(@connection_id : String, @tunnel_id : String, @pending_tcp : PendingTcp)
    end

    # Start reading from client socket and forwarding to CLI
    def start
      @read_fiber = spawn do
        buffer = Bytes.new(8192)
        while @running && !@pending_tcp.closed?
          begin
            size = @pending_tcp.client_socket.read(buffer)
            if size == 0
              # Connection closed
              break
            end
            # Data will be sent via callback set up by TCPIngress
            on_data_received(buffer[0, size])
          rescue ex : IO::Error
            Log.debug { "TCP #{@connection_id} read error: #{ex.message}" }
            break
          end
        end
        close
      end
    end

    # Callback for when data is received from client socket
    @on_data : Proc(Bytes, Nil)?

    def on_data(&block : Bytes ->)
      @on_data = block
    end

    private def on_data_received(data : Bytes)
      @on_data.try(&.call(data))
    end

    # Send data from CLI to client socket
    def send_data(data : Bytes)
      @pending_tcp.send_data(data)
    end

    def close
      return unless @running
      @running = false
      @pending_tcp.close
    end

    def closed? : Bool
      !@running || @pending_tcp.closed?
    end
  end

  # Thread-safe store for pending TCP connections
  class PendingTcpStore
    def initialize
      @connections = {} of String => PendingTcp
      @proxies = {} of String => TcpProxy
      @mutex = Mutex.new
    end

    def add(conn : PendingTcp)
      @mutex.synchronize { @connections[conn.id] = conn }
    end

    def get(id : String) : PendingTcp?
      @mutex.synchronize { @connections[id]? }
    end

    def remove(id : String) : PendingTcp?
      @mutex.synchronize do
        if conn = @connections.delete(id)
          @proxies.delete(id)
          conn
        end
      end
    end

    def set_proxy(id : String, proxy : TcpProxy)
      @mutex.synchronize { @proxies[id] = proxy }
    end

    def get_proxy(id : String) : TcpProxy?
      @mutex.synchronize { @proxies[id]? }
    end

    def remove_by_tunnel(tunnel_id : String) : Int32
      @mutex.synchronize do
        removed = 0
        @connections.reject! do |_, conn|
          if conn.tunnel_id == tunnel_id
            spawn { conn.close }
            removed += 1
            true
          else
            false
          end
        end
        @proxies.reject! { |id, _| @connections[id]?.nil? }
        removed
      end
    end

    def size : Int32
      @mutex.synchronize { @connections.size }
    end

    def cleanup_expired(max_age : Time::Span = 300.seconds)
      @mutex.synchronize do
        now = Time.utc
        @connections.reject! do |_, conn|
          if (now - conn.created_at) > max_age && !conn.closed?
            spawn { conn.close }
            true
          else
            false
          end
        end
      end
    end
  end
end
