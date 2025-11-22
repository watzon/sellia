require "http/server"
require "json"
require "./tunnel_manager"

module Sellia
  class Server
    def initialize(@host : String, @port : Int32, @domain : String)
      @manager = TunnelManager.new
    end

    def start
      server = HTTP::Server.new do |context|
        handle_request(context)
      end

      address = server.bind_tcp(@host, @port)
      puts "Sellia Server listening on http://#{address}"
      server.listen
    end

    private def handle_request(context)
      request = context.request
      response = context.response
      host = request.headers["Host"]?

      # Check if it's a request to the root domain (not a subdomain)
      is_root_domain = false
      if host
        clean_host = host.split(":").first
        is_root_domain = clean_host == @domain
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

      response = {
        id:             agent.client_id,
        port:           agent.port,
        max_conn_count: agent.max_sockets,
        url:            "http://#{agent.client_id}.#{@domain}", # Assuming HTTP for now
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

      # Extract subdomain
      # host: subdomain.domain.com
      clean_host = host.split(":").first

      if clean_host == @domain
        context.response.print "Sellia Server"
        return
      end

      if clean_host.ends_with?(".#{@domain}")
        subdomain = clean_host[0...-(@domain.size + 1)]
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
        # We need to rewrite the Host header? Localtunnel client does this usually.
        # But we are sending the request AS IS to the tunnel socket.
        # The tunnel socket is connected to the Client's TunnelCluster.
        # The Client receives this raw HTTP request and pipes it to the local server.

        context.request.to_io(socket)
        socket.flush

        # Read response
        # We parse the response from the socket and write it to the context response
        client_res = HTTP::Client::Response.from_io(socket)

        context.response.status_code = client_res.status_code
        client_res.headers.each do |key, values|
          values.each { |v| context.response.headers.add(key, v) }
        end

        context.response.print client_res.body

        # Return socket to pool?
        # No, in this simple model, the socket is consumed for one request/response cycle
        # and then closed by the HTTP protocol usually (unless Keep-Alive).
        # But our TunnelAgent logic assumes the socket is "given" and removed from available.
        # If we want to support Keep-Alive on the tunnel link, we'd need to put it back.
        # For now, let's assume one-time use per connection to be safe.
        socket.close
      rescue ex
        context.response.status_code = 502
        context.response.print "Bad Gateway: #{ex.message}"
      end
    end
  end
end
