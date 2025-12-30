require "http/web_socket"
require "log"
require "./client_connection"
require "./connection_manager"
require "./tunnel_registry"
require "./auth_provider"
require "./pending_request"
require "./pending_websocket"
require "./pending_tcp"
require "./rate_limiter"
require "../core/protocol"

module Sellia::Server
  class WSGateway
    Log = ::Log.for("sellia.server.ws")
    property connection_manager : ConnectionManager
    property tunnel_registry : TunnelRegistry
    property auth_provider : AuthProvider
    property pending_requests : PendingRequestStore
    property pending_websockets : PendingWebSocketStore
    property pending_tcps : PendingTcpStore
    property rate_limiter : CompositeRateLimiter
    property domain : String
    property port : Int32
    property use_https : Bool
    property tcp_ingress : TCPIngress?

    PING_INTERVAL = 30.seconds
    PING_TIMEOUT  = 60.seconds

    def initialize(
      @connection_manager : ConnectionManager,
      @tunnel_registry : TunnelRegistry,
      @auth_provider : AuthProvider,
      @pending_requests : PendingRequestStore,
      @pending_websockets : PendingWebSocketStore,
      @pending_tcps : PendingTcpStore,
      @rate_limiter : CompositeRateLimiter,
      @domain : String = "localhost",
      @port : Int32 = 3000,
      @use_https : Bool = false,
      @tcp_ingress : TCPIngress? = nil,
    )
      spawn_heartbeat_loop
    end

    private def spawn_heartbeat_loop
      spawn do
        loop do
          sleep PING_INTERVAL
          check_connections
        end
      end
    end

    private def check_connections
      @connection_manager.each do |client|
        if client.stale?(PING_TIMEOUT)
          Log.warn { "Client #{client.id} timed out (no activity for #{PING_TIMEOUT})" }
          client.close("Connection timeout")
          handle_disconnect(client)
        else
          # Send ping to keep connection alive and detect stale connections
          client.ping
        end
      end
    end

    def handle(socket : HTTP::WebSocket)
      client = ClientConnection.new(socket)
      @connection_manager.add_connection(client)

      Log.debug { "Client connected: #{client.id}" }

      client.on_message do |message|
        handle_message(client, message)
      end

      client.on_close do
        handle_disconnect(client)
      end

      client.run
    end

    private def handle_message(client : ClientConnection, message : Protocol::Message)
      case message
      when Protocol::Messages::Auth
        handle_auth(client, message)
      when Protocol::Messages::TunnelOpen
        handle_tunnel_open(client, message)
      when Protocol::Messages::TunnelClose
        handle_tunnel_close(client, message)
      when Protocol::Messages::ResponseStart
        handle_response_start(client, message)
      when Protocol::Messages::ResponseBody
        handle_response_body(client, message)
      when Protocol::Messages::ResponseEnd
        handle_response_end(client, message)
      when Protocol::Messages::Ping
        client.send(Protocol::Messages::Pong.new(message.timestamp))
      when Protocol::Messages::WebSocketUpgradeOk
        handle_ws_upgrade_ok(client, message)
      when Protocol::Messages::WebSocketUpgradeError
        handle_ws_upgrade_error(client, message)
      when Protocol::Messages::WebSocketFrame
        handle_ws_frame(client, message)
      when Protocol::Messages::WebSocketClose
        handle_ws_close(client, message)
      when Protocol::Messages::TcpOpenOk
        handle_tcp_open_ok(client, message)
      when Protocol::Messages::TcpOpenError
        handle_tcp_open_error(client, message)
      when Protocol::Messages::TcpData
        handle_tcp_data(client, message)
      when Protocol::Messages::TcpClose
        handle_tcp_close(client, message)
      end
    end

    private def handle_auth(client : ClientConnection, message : Protocol::Messages::Auth)
      if @auth_provider.validate(message.api_key)
        client.authenticated = true
        client.api_key = message.api_key

        account_id = @auth_provider.account_id_for(message.api_key)
        client.send(Protocol::Messages::AuthOk.new(
          account_id: account_id,
          limits: {"max_tunnels" => 10_i64, "max_connections" => 100_i64}
        ))

        Log.debug { "Client authenticated: #{client.id}" }
      else
        client.send(Protocol::Messages::AuthError.new("Invalid API key"))
        client.close("Authentication failed")
      end
    end

    private def handle_tunnel_open(client : ClientConnection, message : Protocol::Messages::TunnelOpen)
      # If auth is required, client must be authenticated
      if @auth_provider.require_auth && !client.authenticated
        client.send(Protocol::Messages::AuthError.new("Not authenticated"))
        return
      end

      # Check rate limit for tunnel creation
      unless @rate_limiter.allow_tunnel?(client.id)
        client.send(Protocol::Messages::TunnelClose.new(
          tunnel_id: "",
          reason: "Rate limit exceeded: too many tunnel creations"
        ))
        return
      end

      tunnel_type = message.tunnel_type

      # For TCP tunnels, we need tcp_ingress to be configured
      if tunnel_type == "tcp" && @tcp_ingress.nil?
        client.send(Protocol::Messages::TunnelClose.new(
          tunnel_id: "",
          reason: "TCP tunnels not enabled on this server"
        ))
        return
      end

      # Determine subdomain
      subdomain = message.subdomain
      if subdomain.nil? || subdomain.empty?
        subdomain = @tunnel_registry.generate_subdomain
      else
        # Validate the requested subdomain
        validation = @tunnel_registry.validate_subdomain(subdomain)
        unless validation.valid
          client.send(Protocol::Messages::TunnelClose.new(
            tunnel_id: "",
            reason: validation.error || "Invalid subdomain"
          ))
          return
        end
      end

      # Create tunnel
      tunnel_id = Random::Secure.hex(16)
      tunnel = TunnelRegistry::Tunnel.new(
        id: tunnel_id,
        subdomain: subdomain,
        client_id: client.id,
        auth: message.auth,
        tunnel_type: tunnel_type
      )

      @tunnel_registry.register(tunnel)

      # Build public URL based on tunnel type
      if tunnel_type == "tcp"
        # Allocate port for TCP tunnel
        port = @tcp_ingress.not_nil!.allocate_port(tunnel_id)

        if port.nil?
          @tunnel_registry.unregister(tunnel_id)
          client.send(Protocol::Messages::TunnelClose.new(
            tunnel_id: "",
            reason: "No available ports for TCP tunnel"
          ))
          return
        end

        # TCP URL format: domain:port
        url = "#{@domain}:#{port}"

        client.send(Protocol::Messages::TunnelReady.new(
          tunnel_id: tunnel_id,
          url: url,
          subdomain: subdomain
        ))

        Log.info { "TCP tunnel opened: #{@domain}:#{port} (#{subdomain}) -> client #{client.id}" }
      else
        # HTTP tunnel URL
        protocol = @use_https ? "https" : "http"
        port_suffix = @use_https ? "" : (@port == 80 ? "" : ":#{@port}")
        url = "#{protocol}://#{subdomain}.#{@domain}#{port_suffix}"

        client.send(Protocol::Messages::TunnelReady.new(
          tunnel_id: tunnel_id,
          url: url,
          subdomain: subdomain
        ))

        Log.info { "HTTP tunnel opened: #{subdomain}.#{@domain} -> client #{client.id}" }
      end
    end

    private def handle_tunnel_close(client : ClientConnection, message : Protocol::Messages::TunnelClose)
      if tunnel = @tunnel_registry.find_by_id(message.tunnel_id)
        if tunnel.client_id == client.id
          # Release TCP port if this is a TCP tunnel
          if tunnel.tunnel_type == "tcp"
            @tcp_ingress.try(&.release_port(tunnel.id))
          end

          @tunnel_registry.unregister(message.tunnel_id)
          Log.info { "Tunnel closed: #{tunnel.subdomain} (#{tunnel.tunnel_type})" }
        end
      end
    end

    private def handle_response_start(client : ClientConnection, message : Protocol::Messages::ResponseStart)
      if pending = @pending_requests.get(message.request_id)
        Log.debug { "ResponseStart for #{message.request_id}: status=#{message.status_code}" }
        pending.start_response(message.status_code, message.headers)
      else
        Log.debug { "ResponseStart for unknown request #{message.request_id}" }
      end
    end

    private def handle_response_body(client : ClientConnection, message : Protocol::Messages::ResponseBody)
      if pending = @pending_requests.get(message.request_id)
        Log.debug { "ResponseBody for #{message.request_id}: #{message.chunk.size} bytes" }
        pending.write_body(message.chunk) unless message.chunk.empty?
      else
        Log.debug { "ResponseBody for unknown request #{message.request_id}" }
      end
    end

    private def handle_response_end(client : ClientConnection, message : Protocol::Messages::ResponseEnd)
      if pending = @pending_requests.get(message.request_id)
        Log.debug { "ResponseEnd for #{message.request_id}" }
        pending.finish
      else
        Log.debug { "ResponseEnd for unknown request #{message.request_id}" }
      end
    end

    private def handle_ws_upgrade_ok(client : ClientConnection, message : Protocol::Messages::WebSocketUpgradeOk)
      if pending_ws = @pending_websockets.get(message.request_id)
        Log.debug { "WebSocket upgrade OK for #{message.request_id}" }

        # Signal the HTTP handler that CLI confirmed the connection
        # The actual frame handling is set up in http_ingress.cr
        pending_ws.signal_upgrade_confirmed
      else
        Log.debug { "WebSocket upgrade OK for unknown request #{message.request_id}" }
      end
    end

    private def handle_ws_upgrade_error(client : ClientConnection, message : Protocol::Messages::WebSocketUpgradeError)
      if pending_ws = @pending_websockets.get(message.request_id)
        Log.debug { "WebSocket upgrade error for #{message.request_id}: #{message.message}" }
        pending_ws.fail_upgrade(message.status_code, message.message)
        @pending_websockets.remove(message.request_id)
      end
    end

    private def handle_ws_frame(client : ClientConnection, message : Protocol::Messages::WebSocketFrame)
      # Frame from tunnel client's local WebSocket -> send to external client's WebSocket
      if pending_ws = @pending_websockets.get(message.request_id)
        pending_ws.send_frame(message.opcode, message.payload)
      end
    end

    private def handle_ws_close(client : ClientConnection, message : Protocol::Messages::WebSocketClose)
      if pending_ws = @pending_websockets.remove(message.request_id)
        Log.debug { "WebSocket close for #{message.request_id}" }
        pending_ws.close
      end
    end

    private def handle_disconnect(client : ClientConnection)
      Log.debug { "Client disconnected: #{client.id}" }

      # Remove all tunnels for this client
      tunnels = @tunnel_registry.unregister_client(client.id)
      tunnels.each do |tunnel|
        Log.info { "Tunnel removed: #{tunnel.subdomain} (#{tunnel.tunnel_type})" }

        # Release TCP port if this is a TCP tunnel
        if tunnel.tunnel_type == "tcp"
          @tcp_ingress.try(&.release_port(tunnel.id))
        end

        # Clean up any pending requests for this tunnel
        removed = @pending_requests.remove_by_tunnel(tunnel.id)
        Log.debug { "Cleaned up #{removed} pending requests" } if removed > 0

        # Clean up any pending WebSockets for this tunnel
        ws_removed = @pending_websockets.remove_by_tunnel(tunnel.id)
        Log.debug { "Cleaned up #{ws_removed} pending WebSockets" } if ws_removed > 0

        # Clean up any pending TCP connections for this tunnel
        tcp_removed = @pending_tcps.remove_by_tunnel(tunnel.id)
        Log.debug { "Cleaned up #{tcp_removed} pending TCP connections" } if tcp_removed > 0

        # Reset rate limits for this tunnel
        @rate_limiter.reset_tunnel(tunnel.id)
      end

      # Reset rate limits for this client
      @rate_limiter.reset_client(client.id)

      @connection_manager.unregister(client.id)
    end

    # TCP message handlers

    private def handle_tcp_open_ok(client : ClientConnection, message : Protocol::Messages::TcpOpenOk)
      if pending = @pending_tcps.get(message.connection_id)
        Log.debug { "TCP connection #{message.connection_id} established by CLI" }

        # Create TcpProxy and signal connected
        proxy = TcpProxy.new(message.connection_id, pending.tunnel_id, pending)
        pending.signal_connected(proxy)
      else
        Log.debug { "TCP open OK for unknown connection #{message.connection_id}" }
      end
    end

    private def handle_tcp_open_error(client : ClientConnection, message : Protocol::Messages::TcpOpenError)
      if pending = @pending_tcps.remove(message.connection_id)
        Log.debug { "TCP connection #{message.connection_id} failed: #{message.message}" }
        pending.signal_failed(message.message)
      end
    end

    private def handle_tcp_data(client : ClientConnection, message : Protocol::Messages::TcpData)
      # Forward data to TCP ingress -> external client
      unless ingress = @tcp_ingress
        Log.warn { "Received TCP data but tcp_ingress not configured" }
        return
      end

      unless ingress.send_data(message.connection_id, message.data)
        Log.debug { "Failed to send TCP data for unknown connection #{message.connection_id}" }
      end
    end

    private def handle_tcp_close(client : ClientConnection, message : Protocol::Messages::TcpClose)
      unless ingress = @tcp_ingress
        return
      end

      Log.debug { "TCP close for #{message.connection_id}: #{message.reason}" }
      ingress.close_connection(message.connection_id, message.reason)
    end
  end
end
