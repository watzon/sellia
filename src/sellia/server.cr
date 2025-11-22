require "http/server"
require "json"
require "acme"
require "./tunnel_manager"

module Sellia
  class Server
    def initialize(@host : String, @port : Int32, @domain : String? = nil, @acme_enabled : Bool = false, @acme_email : String = "admin@example.com", @acme_prod : Bool = false)
      @manager = TunnelManager.new
    end

    def start
      if @acme_enabled
        start_with_acme
      else
        start_without_acme
      end
    end

    private def start_without_acme
      server = HTTP::Server.new do |context|
        handle_request(context)
      end

      address = server.bind_tcp(@host, @port)
      puts "Sellia Server listening on http://#{address}"
      server.listen
    end

    private def start_with_acme
      raise "Domain must be specified when using ACME" unless @domain
      directory = @acme_prod ? Acme::Client::LETS_ENCRYPT_PROD : Acme::Client::LETS_ENCRYPT_STAGING
      manager = Acme::Manager.new(directory, @acme_email, ["*.#{@domain}"])

      # Start HTTP Server for Challenges (Port 80)
      spawn do
        http_server = HTTP::Server.new([manager.handler]) do |context|
          # Redirect to HTTPS for non-challenge requests
          context.response.status_code = 301
          context.response.headers["Location"] = "https://#{@domain}#{context.request.resource}"
        end

        puts "Starting ACME Challenge Server on port 80..."
        begin
          http_server.bind_tcp "0.0.0.0", 80
          http_server.listen
        rescue ex
          puts "Error starting ACME HTTP server: #{ex.message}"
          puts "Do you have permission to bind to port 80? (Try sudo)"
          exit 1
        end
      end

      # Give the server a moment to start
      sleep 1.second

      puts "Obtaining certificate for #{@domain}..."
      begin
        cert_pem, key_pem = manager.obtain_certificate
        puts "Certificate obtained successfully!"

        File.write("cert.pem", cert_pem)
        File.write("key.pem", key_pem)

        ssl_context = OpenSSL::SSL::Context::Server.new
        ssl_context.certificate_chain = "cert.pem"
        ssl_context.private_key = "key.pem"

        server = HTTP::Server.new do |context|
          handle_request(context)
        end

        address = server.bind_tls(@host, @port, ssl_context)
        puts "Sellia Server listening on https://#{address}"
        server.listen
      rescue ex
        puts "ACME Error: #{ex.message}"
        exit 1
      end
    end

    private def handle_request(context)
      request = context.request
      response = context.response
      host = request.headers["Host"]?

      # Check if it's a request to the root domain (not a subdomain)
      # Extract the base domain from the host header
      is_root_domain = false
      base_domain = @domain
      if host
        clean_host = host.split(":").first
        # If no domain configured, use the request host as base domain
        base_domain ||= clean_host
        is_root_domain = !clean_host.includes?(".") || (@domain && clean_host == @domain)
      end

      if is_root_domain
        path = request.path

        # API Status
        if path.starts_with?("/api/tunnels/") && path.ends_with?("/status")
          # /api/tunnels/:id/status
          id_part = path[13...-7]
          handle_status(context, id_part)
          return
        end

        if path == "/"
          if request.query_params["new"]?
            handle_registration(context)
            return
          else
            # Redirect to landing page
            context.response.status_code = 302
            context.response.headers["Location"] = "https://localtunnel.github.io/www/"
            return
          end
        elsif path.size > 1 && !path[1..-1].includes?("/")
          # Handle /<id> registration
          subdomain = path[1..-1]

          # Validate subdomain
          unless valid_subdomain?(subdomain)
            context.response.status_code = 403
            context.response.content_type = "application/json"
            context.response.print({message: "Invalid subdomain. Subdomains must be lowercase and between 4 and 63 alphanumeric characters."}.to_json)
            return
          end

          handle_registration(context, subdomain)
          return
        end
      end

      # 2. Handle Proxy Request
      handle_proxy(context)
    end

    private def valid_subdomain?(subdomain)
      /^(?:[a-z0-9][a-z0-9\-]{4,63}[a-z0-9]|[a-z0-9]{4,63})$/.matches?(subdomain)
    end

    private def handle_status(context, id)
      agent = @manager.get_agent(id)
      unless agent
        context.response.status_code = 404
        context.response.print "404"
        return
      end

      context.response.content_type = "application/json"
      context.response.print({connected_sockets: agent.connected_sockets}.to_json)
    end

    private def handle_registration(context, subdomain : String? = nil)
      # Create new client
      agent = @manager.new_client(subdomain)

      # Build URL using request host (like localtunnel does)
      request_host = context.request.headers["Host"]?
      schema = context.request.headers["X-Forwarded-Proto"]? || "http"

      response = {
        id:             agent.client_id,
        port:           agent.port,
        max_conn_count: agent.max_sockets,
        url:            "#{schema}://#{agent.client_id}.#{request_host}",
      }

      context.response.content_type = "application/json"
      context.response.print response.to_json
    end

    private def handle_proxy(context)
      host = context.request.headers["Host"]?
      unless host
        context.response.status_code = 400
        context.response.print "Missing Host header"
        return
      end

      # Extract subdomain from host
      clean_host = host.split(":").first

      # Determine the base domain
      base_domain = @domain
      unless base_domain
        # If no domain configured, extract it from the host
        # Assume format: subdomain.domain.tld
        parts = clean_host.split(".")
        if parts.size >= 2
          base_domain = parts[-2..-1].join(".")
        else
          base_domain = clean_host
        end
      end

      if clean_host == base_domain
        context.response.print "Sellia Server"
        return
      end

      # Extract subdomain
      if clean_host.ends_with?(".#{base_domain}")
        subdomain = clean_host[0...-(base_domain.size + 1)]
      else
        context.response.status_code = 404
        context.response.print "Not found"
        return
      end

      agent = @manager.get_agent(subdomain)
      unless agent
        context.response.status_code = 404
        context.response.print "Tunnel not found"
        return
      end

      begin
        socket = agent.get_socket

        # Forward request
        context.request.to_io(socket)
        socket.flush

        # Read response
        client_res = HTTP::Client::Response.from_io(socket)

        context.response.status_code = client_res.status_code
        client_res.headers.each do |key, values|
          values.each { |v| context.response.headers.add(key, v) }
        end

        context.response.print client_res.body

        # Return socket to pool?
        # For now, let's assume one-time use per connection to be safe.
        socket.close
      rescue ex
        context.response.status_code = 502
        context.response.print "Bad Gateway: #{ex.message}"
      end
    end
  end
end
