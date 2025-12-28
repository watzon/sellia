require "http/web_socket"
require "log"
require "./client_connection"
require "./connection_manager"
require "./tunnel_registry"
require "./auth_provider"
require "./pending_request"
require "./rate_limiter"
require "../core/protocol"

module Sellia::Server
  class WSGateway
    Log = ::Log.for("sellia.server.ws")
    property connection_manager : ConnectionManager
    property tunnel_registry : TunnelRegistry
    property auth_provider : AuthProvider
    property pending_requests : PendingRequestStore
    property rate_limiter : CompositeRateLimiter
    property domain : String
    property port : Int32
    property use_https : Bool

    PING_INTERVAL = 30.seconds
    PING_TIMEOUT  = 60.seconds

    def initialize(
      @connection_manager : ConnectionManager,
      @tunnel_registry : TunnelRegistry,
      @auth_provider : AuthProvider,
      @pending_requests : PendingRequestStore,
      @rate_limiter : CompositeRateLimiter,
      @domain : String = "localhost",
      @port : Int32 = 3000,
      @use_https : Bool = false,
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
        auth: message.auth
      )

      @tunnel_registry.register(tunnel)

      # Build public URL
      protocol = @use_https ? "https" : "http"
      default_port = @use_https ? 443 : 80
      port_suffix = @port == default_port ? "" : ":#{@port}"
      url = "#{protocol}://#{subdomain}.#{@domain}#{port_suffix}"

      client.send(Protocol::Messages::TunnelReady.new(
        tunnel_id: tunnel_id,
        url: url,
        subdomain: subdomain
      ))

      Log.info { "Tunnel opened: #{subdomain}.#{@domain} -> client #{client.id}" }
    end

    private def handle_tunnel_close(client : ClientConnection, message : Protocol::Messages::TunnelClose)
      if tunnel = @tunnel_registry.find_by_id(message.tunnel_id)
        if tunnel.client_id == client.id
          @tunnel_registry.unregister(message.tunnel_id)
          Log.info { "Tunnel closed: #{tunnel.subdomain}" }
        end
      end
    end

    private def handle_response_start(client : ClientConnection, message : Protocol::Messages::ResponseStart)
      if pending = @pending_requests.get(message.request_id)
        pending.start_response(message.status_code, message.headers)
      end
    end

    private def handle_response_body(client : ClientConnection, message : Protocol::Messages::ResponseBody)
      if pending = @pending_requests.get(message.request_id)
        pending.write_body(message.chunk) unless message.chunk.empty?
      end
    end

    private def handle_response_end(client : ClientConnection, message : Protocol::Messages::ResponseEnd)
      if pending = @pending_requests.get(message.request_id)
        pending.finish
      end
    end

    private def handle_disconnect(client : ClientConnection)
      Log.debug { "Client disconnected: #{client.id}" }

      # Remove all tunnels for this client
      tunnels = @tunnel_registry.unregister_client(client.id)
      tunnels.each do |tunnel|
        Log.info { "Tunnel removed: #{tunnel.subdomain}" }

        # Clean up any pending requests for this tunnel
        removed = @pending_requests.remove_by_tunnel(tunnel.id)
        Log.debug { "Cleaned up #{removed} pending requests" } if removed > 0

        # Reset rate limits for this tunnel
        @rate_limiter.reset_tunnel(tunnel.id)
      end

      # Reset rate limits for this client
      @rate_limiter.reset_client(client.id)

      @connection_manager.unregister(client.id)
    end
  end
end
