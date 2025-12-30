require "http/server"
require "http/web_socket"
require "base64"
require "./tunnel_registry"
require "./connection_manager"
require "./pending_request"
require "./pending_websocket"
require "./rate_limiter"
require "./landing"
require "../core/protocol"

module Sellia::Server
  class HTTPIngress
    Log = ::Log.for("sellia.server.ingress")

    property tunnel_registry : TunnelRegistry
    property connection_manager : ConnectionManager
    property pending_requests : PendingRequestStore
    property pending_websockets : PendingWebSocketStore
    property rate_limiter : CompositeRateLimiter
    property domain : String
    property request_timeout : Time::Span
    property landing_enabled : Bool

    def initialize(
      @tunnel_registry : TunnelRegistry,
      @connection_manager : ConnectionManager,
      @pending_requests : PendingRequestStore,
      @pending_websockets : PendingWebSocketStore,
      @rate_limiter : CompositeRateLimiter,
      @domain : String = "localhost",
      @request_timeout : Time::Span = 30.seconds,
      @landing_enabled : Bool = true,
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

      # Check for WebSocket upgrade
      if websocket_upgrade?(request)
        proxy_websocket(context, client, tunnel)
      else
        proxy_request(context, client, tunnel)
      end
    end

    private def websocket_upgrade?(request : HTTP::Request) : Bool
      connection = request.headers["Connection"]?.try(&.downcase) || ""
      upgrade = request.headers["Upgrade"]?.try(&.downcase) || ""
      is_ws = connection.includes?("upgrade") && upgrade == "websocket"

      # Debug logging for WebSocket detection
      unless is_ws
        Log.debug { "Not a WebSocket upgrade: Connection=#{connection.inspect}, Upgrade=#{upgrade.inspect}" }
      end

      is_ws
    end

    private def proxy_websocket(context : HTTP::Server::Context, client : ClientConnection, tunnel : TunnelRegistry::Tunnel)
      request_id = Random::Secure.hex(16)

      Log.debug { "WebSocket upgrade #{request_id}: #{context.request.resource} -> tunnel #{tunnel.subdomain}" }

      # Build headers including WebSocket-specific ones, preserving all values
      headers = {} of String => Array(String)
      context.request.headers.each do |key, values|
        headers[key] = values
      end

      # Create pending WebSocket tracking
      pending_ws = PendingWebSocket.new(request_id, context, tunnel.id)
      @pending_websockets.add(pending_ws)

      # Check for required WebSocket headers
      ws_key = context.request.headers["Sec-WebSocket-Key"]?
      ws_version = context.request.headers["Sec-WebSocket-Version"]?
      ws_protocol_header = context.request.headers["Sec-WebSocket-Protocol"]?

      unless ws_key && ws_version == "13"
        @pending_websockets.remove(request_id)
        context.response.status_code = 400
        context.response.content_type = "text/plain"
        context.response.print("Invalid WebSocket handshake")
        return
      end

      # Send upgrade request to client
      unless client.send(Protocol::Messages::WebSocketUpgrade.new(
               request_id: request_id,
               tunnel_id: tunnel.id,
               path: context.request.resource,
               headers: headers
             ))
        @pending_websockets.remove(request_id)
        context.response.status_code = 502
        context.response.print("Tunnel client disconnected")
        return
      end

      # Write the WebSocket handshake response headers before upgrade.
      # response.upgrade only writes headers as-is; it doesn't set them.
      context.response.status = :switching_protocols
      context.response.headers["Upgrade"] = "websocket"
      context.response.headers["Connection"] = "Upgrade"
      context.response.headers["Sec-WebSocket-Accept"] = HTTP::WebSocket::Protocol.key_challenge(ws_key)
      if selected_protocol = select_websocket_protocol(ws_protocol_header)
        context.response.headers["Sec-WebSocket-Protocol"] = selected_protocol
      end

      # Use response.upgrade to keep the handler alive and access the underlying IO
      context.response.upgrade do |io|
        Log.info { "WebSocket #{request_id}: upgrade handler executing, waiting for CLI confirmation" }

        # Wait for CLI to confirm local connection before starting frame loop
        # This times out if the CLI doesn't respond
        unless pending_ws.wait_for_upgrade(@request_timeout)
          Log.warn { "WebSocket #{request_id}: upgrade timeout - CLI did not confirm" }
          next
        end

        Log.info { "WebSocket #{request_id}: CLI confirmed, starting frame reader" }

        # Create WebSocket protocol instance for reading frames from the external client
        # Server-side means unmasked reads, masked writes
        ws_protocol = HTTP::WebSocket::Protocol.new(io, masked: false, sync_close: false)

        # Store the protocol in pending_ws so it can be used to send frames back to the client
        pending_ws.ws_protocol = ws_protocol

        # Set up frame forwarding from external client to tunnel client
        pending_ws.on_frame do |opcode, payload|
          Log.debug { "WebSocket #{request_id}: forwarding frame to CLI: opcode=#{opcode}, size=#{payload.size}" }
          client.send(Protocol::Messages::WebSocketFrame.new(
            request_id: request_id,
            opcode: opcode,
            payload: payload
          ))
        end

        pending_ws.on_close do |code|
          Log.info { "WebSocket #{request_id}: external client closed, code=#{code.inspect}" }
          client.send(Protocol::Messages::WebSocketClose.new(
            request_id: request_id,
            code: code
          ))
          @pending_websockets.remove(request_id)
        end

        # Run the frame reading loop
        run_websocket_frame_loop(request_id, ws_protocol, pending_ws, io)
      end

      Log.debug { "WebSocket #{request_id} connection closed, removing from store" }
      @pending_websockets.remove(request_id)
    end

    private def select_websocket_protocol(header : String?) : String?
      return nil unless header
      header.split(',').map(&.strip).reject(&.empty?).first?
    end

    # Run the WebSocket frame reading loop
    private def run_websocket_frame_loop(request_id : String, ws_protocol : HTTP::WebSocket::Protocol, pending_ws : PendingWebSocket, io : IO)
      buffer = Bytes.new(8192)

      Log.info { "WebSocket #{request_id}: starting frame loop" }

      # Main frame reading loop
      loop do
        break if pending_ws.closed?

        begin
          # Read a frame
          info = ws_protocol.receive(buffer)

          Log.debug { "WebSocket #{request_id}: received frame opcode=#{info.opcode}, size=#{info.size}, final=#{info.final}" }

          case info.opcode
          when HTTP::WebSocket::Protocol::Opcode::PING
            # Respond to ping with pong automatically
            payload = buffer[0, info.size]
            Log.debug { "WebSocket #{request_id}: received ping, sending pong" }
            ws_protocol.pong(payload.empty? ? nil : String.new(payload))
          when HTTP::WebSocket::Protocol::Opcode::PONG
            # Pong received, ignore (unsolicited pong)
            Log.debug { "WebSocket #{request_id}: received pong" }
          when HTTP::WebSocket::Protocol::Opcode::CLOSE
            # Close frame - notify and close
            Log.info { "WebSocket #{request_id}: received close frame" }
            pending_ws.handle_close(nil)
            # Send close response
            ws_protocol.close
            break
          when HTTP::WebSocket::Protocol::Opcode::TEXT
            # Text frame - forward to CLI
            payload = Bytes.new(info.size)
            payload.copy_from(buffer.to_unsafe, info.size)

            if info.final
              Log.debug { "WebSocket #{request_id}: received text frame: #{String.new(payload)}" }
              pending_ws.handle_frame(0x01_u8, payload)
            end
          when HTTP::WebSocket::Protocol::Opcode::BINARY
            # Binary frame - forward to CLI
            payload = Bytes.new(info.size)
            payload.copy_from(buffer.to_unsafe, info.size)

            if info.final
              Log.debug { "WebSocket #{request_id}: received binary frame, #{info.size} bytes" }
              pending_ws.handle_frame(0x02_u8, payload)
            end
          when HTTP::WebSocket::Protocol::Opcode::CONTINUATION
            # Continuation frame - accumulate and forward when final
            payload = Bytes.new(info.size)
            payload.copy_from(buffer.to_unsafe, info.size)

            if info.final
              Log.debug { "WebSocket #{request_id}: received continuation frame, #{info.size} bytes (final)" }
              pending_ws.handle_frame(0x00_u8, payload)
            end
          else
            Log.warn { "WebSocket #{request_id}: unknown opcode #{info.opcode}" }
          end
        rescue ex : IO::Error
          Log.info { "WebSocket #{request_id}: IO error (connection closed): #{ex.message}" }
          pending_ws.handle_close(nil)
          break
        rescue ex : Exception
          Log.error { "WebSocket #{request_id}: error in frame loop: #{ex.class}: #{ex.message}" }
          Log.error { ex.backtrace.join("\n") }
          pending_ws.handle_close(nil)
          break
        end
      end

      Log.info { "WebSocket #{request_id}: frame loop ended" }
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
        # Serve landing page if enabled, otherwise simple text response
        if @landing_enabled && Landing.serve(context)
          # Landing page served successfully
        else
          context.response.content_type = "text/plain"
          context.response.print("Sellia Tunnel Server\n\nConnect with: sellia http <port>")
        end
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

      Log.debug { "Proxying request #{request_id}: #{context.request.method} #{context.request.resource} -> tunnel #{tunnel.subdomain}" }

      # Create pending request
      pending = PendingRequest.new(request_id, context, tunnel.id)
      @pending_requests.add(pending)

      # Build headers hash, preserving all values
      headers = {} of String => Array(String)
      context.request.headers.each do |key, values|
        headers[key] = values
      end

      # Send request start to client
      unless client.send(Protocol::Messages::RequestStart.new(
               request_id: request_id,
               tunnel_id: tunnel.id,
               method: context.request.method,
               path: context.request.resource,
               headers: headers
             ))
        Log.warn { "Failed to send RequestStart for #{request_id} - client disconnected" }
        @pending_requests.remove(request_id)
        context.response.status_code = 502
        context.response.print("Tunnel client disconnected")
        return
      end

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
        Log.warn { "Request #{request_id} timed out after #{@request_timeout}" }
        @pending_requests.remove(request_id)
        # Only set status if headers haven't been sent yet
        unless pending.response_started
          context.response.status_code = 504
          context.response.print("Gateway timeout - no response from tunnel")
        end
        return
      end

      Log.debug { "Request #{request_id} completed" }
      @pending_requests.remove(request_id)
    end
  end
end
