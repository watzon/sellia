require "mutex"

module Sellia::Server
  class TunnelRegistry
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
