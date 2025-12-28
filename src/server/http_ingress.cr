require "http/server"
require "base64"
require "./tunnel_registry"
require "./connection_manager"
require "./pending_request"
require "./rate_limiter"
require "../core/protocol"

module Sellia::Server
  class HTTPIngress
    property tunnel_registry : TunnelRegistry
    property connection_manager : ConnectionManager
    property pending_requests : PendingRequestStore
    property rate_limiter : CompositeRateLimiter
    property domain : String
    property request_timeout : Time::Span

    def initialize(
      @tunnel_registry : TunnelRegistry,
      @connection_manager : ConnectionManager,
      @pending_requests : PendingRequestStore,
      @rate_limiter : CompositeRateLimiter,
      @domain : String = "localhost",
      @request_timeout : Time::Span = 30.seconds,
    )
    end

    def handle(context : HTTP::Server::Context) : Nil
      request = context.request
      host = request.headers["Host"]?

      unless host
        context.response.status_code = 400
        context.response.content_type = "text/plain"
        context.response.print("Missing Host header")
        return
      end

      # Extract subdomain
      subdomain = extract_subdomain(host)

      unless subdomain
        # Root domain request - could serve API or info page
        serve_root(context)
        return
      end

      # Find tunnel for subdomain
      tunnel = @tunnel_registry.find_by_subdomain(subdomain)

      unless tunnel
        context.response.status_code = 404
        context.response.content_type = "text/plain"
        context.response.print("Tunnel not found: #{subdomain}")
        return
      end

      # Check basic auth if configured
      if tunnel.auth
        unless check_basic_auth(context, tunnel.auth.not_nil!)
          context.response.status_code = 401
          context.response.headers["WWW-Authenticate"] = "Basic realm=\"Tunnel\""
          context.response.print("Unauthorized")
          return
        end
      end

      # Check rate limit for this tunnel
      unless @rate_limiter.allow_request?(tunnel.id)
        context.response.status_code = 429
        context.response.content_type = "text/plain"
        context.response.headers["Retry-After"] = "1"
        context.response.print("Rate limit exceeded")
        return
      end

      # Find client connection
      client = @connection_manager.find(tunnel.client_id)

      unless client
        context.response.status_code = 502
        context.response.content_type = "text/plain"
        context.response.print("Tunnel client disconnected")
        return
      end

      # Proxy the request
      proxy_request(context, client, tunnel)
    end

    private def extract_subdomain(host : String) : String?
      # Remove port if present
      host = host.split(":").first

      # Check if it's a subdomain of our domain
      # Handle the domain itself potentially having a port in its definition
      domain_without_port = @domain.split(":").first

      if host.ends_with?(".#{domain_without_port}")
        host[0, host.size - domain_without_port.size - 1]
      elsif host == domain_without_port
        nil
      else
        # Could be custom domain in future
        nil
      end
    end

    private def serve_root(context : HTTP::Server::Context)
      case context.request.path
      when "/health"
        context.response.content_type = "application/json"
        context.response.print(%({"status":"ok","tunnels":#{@tunnel_registry.size}}))
      when "/tunnel/verify"
        # Caddy on-demand TLS verification endpoint
        # Returns 200 if subdomain has active tunnel, 404 otherwise
        verify_tunnel_for_tls(context)
      else
        context.response.content_type = "text/plain"
        context.response.print("Sellia Tunnel Server\n\nConnect with: sellia http <port>")
      end
    end

    # Verify if a domain should get a TLS certificate (for Caddy on-demand TLS)
    private def verify_tunnel_for_tls(context : HTTP::Server::Context)
      domain_param = context.request.query_params["domain"]?

      unless domain_param
        context.response.status_code = 400
        context.response.content_type = "text/plain"
        context.response.print("Missing domain parameter")
        return
      end

      # Extract subdomain from the full domain
      subdomain = extract_subdomain(domain_param)

      # Allow the base domain (for WebSocket connections from clients)
      # Also allow subdomains that have active tunnels
      domain_without_port = @domain.split(":").first
      is_base_domain = domain_param == domain_without_port

      if is_base_domain || (subdomain && @tunnel_registry.find_by_subdomain(subdomain))
        # Base domain or active tunnel - allow certificate
        context.response.status_code = 200
        context.response.content_type = "text/plain"
        context.response.print("OK")
      else
        # No active tunnel - deny certificate
        context.response.status_code = 404
        context.response.content_type = "text/plain"
        context.response.print("No active tunnel for #{domain_param}")
      end
    end

    private def check_basic_auth(context : HTTP::Server::Context, expected : String) : Bool
      auth_header = context.request.headers["Authorization"]?
      return false unless auth_header

      parts = auth_header.split(" ", 2)
      return false unless parts.size == 2 && parts[0].downcase == "basic"

      begin
        decoded = Base64.decode_string(parts[1])
        decoded == expected
      rescue
        false
      end
    end

    private def proxy_request(context : HTTP::Server::Context, client : ClientConnection, tunnel : TunnelRegistry::Tunnel)
      request_id = Random::Secure.hex(16)

      # Create pending request
      pending = PendingRequest.new(request_id, context, tunnel.id)
      @pending_requests.add(pending)

      # Build headers hash
      headers = {} of String => String
      context.request.headers.each do |key, values|
        headers[key] = values.first
      end

      # Send request start to client
      client.send(Protocol::Messages::RequestStart.new(
        request_id: request_id,
        tunnel_id: tunnel.id,
        method: context.request.method,
        path: context.request.resource,
        headers: headers
      ))

      # Send request body if present
      if body = context.request.body
        buffer = Bytes.new(8192)
        while (read = body.read(buffer)) > 0
          chunk = buffer[0, read].dup
          client.send(Protocol::Messages::RequestBody.new(
            request_id: request_id,
            chunk: chunk,
            final: false
          ))
        end
      end

      # Send final empty chunk to indicate end of request body
      client.send(Protocol::Messages::RequestBody.new(
        request_id: request_id,
        chunk: Bytes.empty,
        final: true
      ))

      # Wait for response with timeout
      unless pending.wait(@request_timeout)
        @pending_requests.remove(request_id)
        # Only set status if headers haven't been sent yet
        unless pending.response_started
          context.response.status_code = 504
          context.response.print("Gateway timeout - no response from tunnel")
        end
        return
      end

      @pending_requests.remove(request_id)
    end
  end
end
