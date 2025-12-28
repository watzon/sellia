require "mutex"

module Sellia::Server
  class TunnelRegistry
    # Reserved subdomains that cannot be claimed
    @@reserved_subdomains = Set{
      "api", "www", "admin", "app", "dashboard", "console",
      "mail", "smtp", "imap", "pop", "ftp", "ssh", "sftp",
      "cdn", "static", "assets", "media", "images", "files",
      "auth", "login", "oauth", "sso", "account", "accounts",
      "billing", "pay", "payment", "payments", "subscribe",
      "help", "support", "docs", "documentation", "status",
      "blog", "news", "forum", "community", "dev", "developer",
      "test", "staging", "demo", "sandbox", "preview",
      "ws", "wss", "socket", "websocket", "stream",
      "git", "svn", "repo", "registry", "npm", "pypi",
      "internal", "private", "public", "local", "localhost",
      "root", "system", "server", "servers", "node", "nodes",
      "sellia", "tunnel", "tunnels", "proxy",
    }

    # Validation result
    struct ValidationResult
      property valid : Bool
      property error : String?

      def initialize(@valid : Bool, @error : String? = nil)
      end
    end

    struct Tunnel
      property id : String
      property subdomain : String
      property client_id : String
      property created_at : Time
      property auth : String?

      def initialize(@id : String, @subdomain : String, @client_id : String, @auth : String? = nil)
        @created_at = Time.utc
      end
    end

    def initialize
      @tunnels = {} of String => Tunnel       # id -> tunnel
      @by_subdomain = {} of String => Tunnel  # subdomain -> tunnel
      @by_client = {} of String => Array(Tunnel)  # client_id -> tunnels
      @mutex = Mutex.new
    end

    def register(tunnel : Tunnel) : Nil
      @mutex.synchronize do
        @tunnels[tunnel.id] = tunnel
        @by_subdomain[tunnel.subdomain] = tunnel

        @by_client[tunnel.client_id] ||= [] of Tunnel
        @by_client[tunnel.client_id] << tunnel
      end
    end

    def unregister(tunnel_id : String) : Tunnel?
      @mutex.synchronize do
        if tunnel = @tunnels.delete(tunnel_id)
          @by_subdomain.delete(tunnel.subdomain)

          if client_tunnels = @by_client[tunnel.client_id]?
            client_tunnels.reject! { |t| t.id == tunnel_id }
            @by_client.delete(tunnel.client_id) if client_tunnels.empty?
          end

          tunnel
        end
      end
    end

    def find_by_id(id : String) : Tunnel?
      @mutex.synchronize { @tunnels[id]? }
    end

    def find_by_subdomain(subdomain : String) : Tunnel?
      @mutex.synchronize { @by_subdomain[subdomain]? }
    end

    def find_by_client(client_id : String) : Array(Tunnel)
      @mutex.synchronize { @by_client[client_id]?.try(&.dup) || [] of Tunnel }
    end

    def subdomain_available?(subdomain : String) : Bool
      @mutex.synchronize { !@by_subdomain.has_key?(subdomain) }
    end

    # Validate subdomain according to DNS label rules and security constraints
    def validate_subdomain(subdomain : String) : ValidationResult
      # Length check (DNS label: 1-63 chars, we require 3+ for usability)
      if subdomain.size < 3
        return ValidationResult.new(false, "Subdomain must be at least 3 characters")
      end

      if subdomain.size > 63
        return ValidationResult.new(false, "Subdomain must be at most 63 characters")
      end

      # Character validation (alphanumeric and hyphens only)
      unless subdomain.matches?(/\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/i) || subdomain.matches?(/\A[a-z0-9]{3}\z/i)
        if subdomain.starts_with?("-") || subdomain.ends_with?("-")
          return ValidationResult.new(false, "Subdomain cannot start or end with a hyphen")
        end
        if subdomain.includes?("--")
          return ValidationResult.new(false, "Subdomain cannot contain consecutive hyphens")
        end
        return ValidationResult.new(false, "Subdomain can only contain lowercase letters, numbers, and hyphens")
      end

      # Reserved names check
      normalized = subdomain.downcase
      if @@reserved_subdomains.includes?(normalized)
        return ValidationResult.new(false, "Subdomain '#{subdomain}' is reserved")
      end

      # Check availability
      unless subdomain_available?(subdomain)
        return ValidationResult.new(false, "Subdomain '#{subdomain}' is not available")
      end

      ValidationResult.new(true)
    end

    def generate_subdomain : String
      1000.times do
        subdomain = Random::Secure.hex(4)
        return subdomain if subdomain_available?(subdomain)
      end
      raise "Failed to generate unique subdomain after 1000 attempts"
    end

    def size : Int32
      @mutex.synchronize { @tunnels.size }
    end

    def unregister_client(client_id : String) : Array(Tunnel)
      @mutex.synchronize do
        removed = [] of Tunnel
        if tunnels = @by_client.delete(client_id)
          tunnels.each do |tunnel|
            @tunnels.delete(tunnel.id)
            @by_subdomain.delete(tunnel.subdomain)
            removed << tunnel
          end
        end
        removed
      end
    end
  end
end
