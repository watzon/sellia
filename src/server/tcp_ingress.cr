require "socket"
require "log"
require "mutex"
require "./tunnel_registry"
require "./connection_manager"
require "./pending_tcp"
require "./rate_limiter"
require "./port_allocator"
require "../core/protocol"

module Sellia::Server
  # TCP ingress server handles incoming TCP connections for TCP tunnels
  #
  # Listens on allocated ports and forwards connections to the tunnel client
  class TCPIngress
    Log = ::Log.for("sellia.server.tcp")

    property tunnel_registry : TunnelRegistry
    property connection_manager : ConnectionManager
    property pending_tcps : PendingTcpStore
    property rate_limiter : CompositeRateLimiter
    property port_allocator : PortAllocator
    property host : String

    @listeners : Hash(Int32, TCPServer) = {} of Int32 => TCPServer
    @listener_mutex : Mutex = Mutex.new
    @running : Bool = false

    def initialize(
      @tunnel_registry : TunnelRegistry,
      @connection_manager : ConnectionManager,
      @pending_tcps : PendingTcpStore,
      @rate_limiter : CompositeRateLimiter,
      @port_allocator : PortAllocator,
      @host : String = "0.0.0.0",
    )
    end

    # Start the TCP ingress - begin listening for new tunnels
    def start
      @running = true

      # Spawn cleanup task for expired connections
      spawn do
        while @running
          sleep 60.seconds
          @pending_tcps.cleanup_expired
        end
      end
    end

    # Allocate a port for a new TCP tunnel and start listening
    def allocate_port(tunnel_id : String) : Int32?
      port = @port_allocator.allocate(tunnel_id)
      if port
        Log.info { "Allocated port #{port} for TCP tunnel #{tunnel_id}" }
        # Spawn listener for this port
        spawn start_listener(port, tunnel_id)
      end
      port
    end

    # Release a port when tunnel closes
    def release_port(tunnel_id : String) : Int32?
      if port = @port_allocator.get_port(tunnel_id)
        @port_allocator.release(port)

        # Stop listening on this port
        @listener_mutex.synchronize do
          if server = @listeners.delete(port)
            begin
              server.close
            rescue
            end
          end
        end

        # Close any pending connections for this tunnel
        @pending_tcps.remove_by_tunnel(tunnel_id)

        Log.info { "Released port #{port} for TCP tunnel #{tunnel_id}" }
        port
      end
    end

    # Start a listener on a specific port
    private def start_listener(port : Int32, tunnel_id : String)
      tunnel = @tunnel_registry.find_by_id(tunnel_id)
      return unless tunnel

      client = @connection_manager.find(tunnel.client_id)
      return unless client

      begin
        server = TCPServer.new(@host, port)

        @listener_mutex.synchronize do
          @listeners[port] = server
        end

        Log.info { "TCP listener started on port #{port} for tunnel #{tunnel.subdomain}" }

        while @running
          begin
            # Accept incoming connection
            client_socket = server.accept
            remote_addr = client_socket.remote_address.to_s

            Log.debug { "TCP connection on port #{port} from #{remote_addr}" }

            # Check rate limit
            unless @rate_limiter.allow_request?(tunnel_id)
              client_socket.close
              Log.warn { "TCP rate limit exceeded for tunnel #{tunnel_id}" }
              next
            end

            # Handle this connection
            spawn handle_tcp_connection(client_socket, client, tunnel, remote_addr)
          rescue ex : IO::Error
            break if !@running
          end
        end
      rescue ex : Exception
        Log.error { "TCP listener on port #{port} failed: #{ex.message}" }
      ensure
        @listener_mutex.synchronize do
          @listeners.delete(port)
        end
        server.try(&.close) rescue nil
      end
    end

    private def handle_tcp_connection(client_socket : TCPSocket, ws_client : ClientConnection, tunnel : TunnelRegistry::Tunnel, remote_addr : String)
      connection_id = Random::Secure.hex(16)

      pending = PendingTcp.new(connection_id, tunnel.id, remote_addr, client_socket)
      @pending_tcps.add(pending)

      # Send TcpOpen to CLI
      ws_client.send(Protocol::Messages::TcpOpen.new(
        connection_id: connection_id,
        tunnel_id: tunnel.id,
        remote_addr: remote_addr
      ))

      # Wait for CLI to establish local connection
      unless pending.wait_for_connection(30.seconds)
        Log.warn { "TCP connection #{connection_id} timeout waiting for CLI" }
        @pending_tcps.remove(connection_id)
        begin
          client_socket.close
        rescue
        end
        return
      end

      proxy = pending.tcp_proxy
      unless proxy
        Log.warn { "TCP connection #{connection_id} has no proxy" }
        return
      end

      @pending_tcps.set_proxy(connection_id, proxy)

      # Set up data forwarding from CLI to client
      proxy.on_data do |data|
        pending.send_data(data)
      end

      # Start reading from client socket
      proxy.start

      Log.info { "TCP connection #{connection_id} established from #{remote_addr}" }
    rescue ex : Exception
      Log.error { "Error handling TCP connection: #{ex.message}" }
    end

    # Send data from CLI to TCP client
    def send_data(connection_id : String, data : Bytes) : Bool
      if proxy = @pending_tcps.get_proxy(connection_id)
        proxy.send_data(data)
        true
      else
        false
      end
    end

    # Close a TCP connection
    def close_connection(connection_id : String, reason : String? = nil)
      if pending = @pending_tcps.remove(connection_id)
        pending.close(reason)
      end
    end

    def stop
      @running = false

      # Close all listeners
      @listener_mutex.synchronize do
        @listeners.each_value do |server|
          begin
            server.close
          rescue
          end
        end
        @listeners.clear
      end

      # Close all pending connections
      @pending_tcps.size.times do
        # Connections will be cleaned up
      end
    end
  end
end
