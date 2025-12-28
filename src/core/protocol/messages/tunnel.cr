require "../message"

module Sellia::Protocol::Messages
  # Request to open a tunnel
  class TunnelOpen < Message
    property type : String = "tunnel_open"
    property tunnel_type : String # "http" or "tcp"
    property local_port : Int32
    property subdomain : String? # Optional: custom subdomain
    property auth : String?      # Optional: "user:pass" for basic auth

    def initialize(
      @tunnel_type : String,
      @local_port : Int32,
      @subdomain : String? = nil,
      @auth : String? = nil,
    )
    end
  end

  # Tunnel is ready and accepting connections
  class TunnelReady < Message
    property type : String = "tunnel_ready"
    property tunnel_id : String
    property url : String
    property subdomain : String

    def initialize(@tunnel_id : String, @url : String, @subdomain : String)
    end
  end

  # Tunnel closed notification
  class TunnelClose < Message
    property type : String = "tunnel_close"
    property tunnel_id : String
    property reason : String?

    def initialize(@tunnel_id : String, @reason : String? = nil)
    end
  end
end
