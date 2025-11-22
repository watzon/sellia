require "./tunnel_agent"
require "uuid"

module Sellia
  class TunnelManager
    def initialize
      @agents = Hash(String, TunnelAgent).new
    end

    def new_client(id : String? = nil) : TunnelAgent
      client_id = id || UUID.random.to_s[0...8] # Simple random ID

      # Ensure uniqueness
      while @agents.has_key?(client_id)
        client_id = UUID.random.to_s[0...8]
      end

      agent = TunnelAgent.new(client_id)
      @agents[client_id] = agent
      agent.listen

      agent
    end

    def get_agent(id : String) : TunnelAgent?
      @agents[id]?
    end

    def remove_client(id : String)
      if agent = @agents.delete(id)
        agent.close
      end
    end

    def has_client?(id : String) : Bool
      @agents.has_key?(id)
    end

    def open_tunnels_count : Int32
      @agents.size
    end
  end
end
