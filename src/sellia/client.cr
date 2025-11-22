require "http/client"
require "json"
require "uri"
require "./tunnel_cluster"

module Sellia
  class Client
    def initialize(@server_host : String, @server_port : Int32, @local_port : Int32, @subdomain : String?, @local_host : String = "localhost")
    end

    getter public_url : String?
    @cluster : TunnelCluster?

    def start
      # Normalize the server URL - add protocol if not present
      has_protocol = @server_host.starts_with?("http://") || @server_host.starts_with?("https://")
      is_https = @server_host.starts_with?("https://")
      base_url = has_protocol ? @server_host : "http://#{@server_host}"

      # Only append port if it's non-standard (not 80 for HTTP, not 443 for HTTPS)
      default_port = is_https ? 443 : 80
      needs_port = @server_port != default_port

      # 1. Request new tunnel from the API
      url_with_port = needs_port ? "#{base_url}:#{@server_port}" : base_url
      url = if sub = @subdomain
              "#{url_with_port}/#{sub}"
            else
              "#{url_with_port}/?new"
            end

      puts "Requesting tunnel from #{url}..."

      begin
        response = HTTP::Client.get(url)
        unless response.status_code == 200
          puts "Error requesting tunnel: #{response.status_code} #{response.body}"
          return # Don't exit, just return for test safety
        end

        data = JSON.parse(response.body)
        tunnel_port = data["port"].as_i
        tunnel_id = data["id"].as_s
        max_conn = data["max_conn_count"].as_i
        @public_url = data["url"].as_s

        puts "Tunnel established at #{@public_url}"
        puts "Forwarding to localhost:#{@local_port}"

        # For localtunnel.me, help users with the consent page by showing their public IP
        if @server_host.includes?("localtunnel.me") || @server_host.includes?("loca.lt")
          begin
            ip_response = HTTP::Client.get("https://api.ipify.org")
            if ip_response.status_code == 200
              public_ip = ip_response.body.strip
              puts ""
              puts "==> Your public IP is: #{public_ip}"
              puts "    (You may need this for the localtunnel consent page)"
              puts ""
            end
          rescue
            # Silently ignore if we can't fetch the IP
          end
        end

        # 2. Start Tunnel Cluster
        # Extract hostname from server_host URL (matches localtunnel's parse(host).hostname)
        remote_hostname = URI.parse(@server_host).hostname || @server_host
        cluster = TunnelCluster.new(remote_hostname, tunnel_port, @local_port, max_conn, @local_host)
        @cluster = cluster
        cluster.start
      rescue ex
        puts "Error: #{ex.message}"
        # exit 1 # Don't exit in tests
      end
    end

    def stop
      @cluster.try &.stop
    end
  end
end
