require "http/web_socket"
require "./client_connection"
require "./connection_manager"
require "./tunnel_registry"
require "./auth_provider"
require "./pending_request"
require "../core/protocol"

module Sellia::Server
  class WSGateway
    property connection_manager : ConnectionManager
    property tunnel_registry : TunnelRegistry
    property auth_provider : AuthProvider
    property pending_requests : PendingRequestStore
    property domain : String
    property use_https : Bool

    def initialize(
      @connection_manager : ConnectionManager,
      @tunnel_registry : TunnelRegistry,
      @auth_provider : AuthProvider,
      @pending_requests : PendingRequestStore,
      @domain : String = "localhost",
      @use_https : Bool = false
    )
    end

    def handle(socket : HTTP::WebSocket)
      client = ClientConnection.new(socket)
      @connection_manager.add_connection(client)

      puts "[WS] Client connected: #{client.id}"

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

        puts "[WS] Client authenticated: #{client.id}"
      else
        client.send(Protocol::Messages::AuthError.new("Invalid API key"))
        client.close("Authentication failed")
      end
    end

    private def handle_tunnel_open(client : ClientConnection, message : Protocol::Messages::TunnelOpen)
      unless client.authenticated
        client.send(Protocol::Messages::AuthError.new("Not authenticated"))
        return
      end

      # Determine subdomain
      subdomain = message.subdomain
      if subdomain.nil? || subdomain.empty?
        subdomain = @tunnel_registry.generate_subdomain
      elsif !@tunnel_registry.subdomain_available?(subdomain)
        client.send(Protocol::Messages::TunnelClose.new(
          tunnel_id: "",
          reason: "Subdomain '#{subdomain}' is not available"
        ))
        return
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
      url = "#{protocol}://#{subdomain}.#{@domain}"

      client.send(Protocol::Messages::TunnelReady.new(
        tunnel_id: tunnel_id,
        url: url,
        subdomain: subdomain
      ))

      puts "[WS] Tunnel opened: #{subdomain}.#{@domain} -> client #{client.id}"
    end

    private def handle_tunnel_close(client : ClientConnection, message : Protocol::Messages::TunnelClose)
      if tunnel = @tunnel_registry.find_by_id(message.tunnel_id)
        if tunnel.client_id == client.id
          @tunnel_registry.unregister(message.tunnel_id)
          puts "[WS] Tunnel closed: #{tunnel.subdomain}"
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
      puts "[WS] Client disconnected: #{client.id}"

      # Remove all tunnels for this client
      tunnels = @tunnel_registry.unregister_client(client.id)
      tunnels.each do |tunnel|
        puts "[WS] Tunnel removed: #{tunnel.subdomain}"
      end

      @connection_manager.unregister(client.id)
    end
  end
end
