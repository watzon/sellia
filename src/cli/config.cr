require "yaml"

module Sellia::CLI
  class Config
    include YAML::Serializable

    class Inspector
      include YAML::Serializable

      @[YAML::Field(key: "port")]
      property port : Int32 = 4040

      @[YAML::Field(key: "open")]
      property open : Bool = false

      def initialize(@port : Int32 = 4040, @open : Bool = false)
      end

      def merge(other : Inspector) : Inspector
        Inspector.new(
          port: other.port != 4040 ? other.port : @port,
          open: other.open || @open
        )
      end

      def to_yaml(yaml : YAML::Nodes::Builder)
        yaml.mapping do
          yaml.scalar "port"
          yaml.scalar @port
          yaml.scalar "open"
          yaml.scalar @open
        end
      end
    end

    class TunnelConfig
      include YAML::Serializable

      @[YAML::Field(key: "type")]
      property type : String = "http"

      @[YAML::Field(key: "port")]
      property port : Int32

      @[YAML::Field(key: "subdomain")]
      property subdomain : String?

      @[YAML::Field(key: "auth")]
      property auth : String?

      @[YAML::Field(key: "local_host")]
      property local_host : String = "localhost"

      def initialize(
        @port : Int32,
        @type : String = "http",
        @subdomain : String? = nil,
        @auth : String? = nil,
        @local_host : String = "localhost",
      )
      end
    end

    @[YAML::Field(key: "server")]
    property server : String = "https://to.sellia.me"

    @[YAML::Field(key: "api_key")]
    property api_key : String?

    @[YAML::Field(key: "inspector")]
    property inspector : Inspector = Inspector.new

    @[YAML::Field(key: "tunnels")]
    property tunnels : Hash(String, TunnelConfig) = {} of String => TunnelConfig

    def initialize(
      @server : String = "https://to.sellia.me",
      @api_key : String? = nil,
      @inspector : Inspector = Inspector.new,
      @tunnels : Hash(String, TunnelConfig) = {} of String => TunnelConfig,
    )
    end

    def merge(other : Config) : Config
      Config.new(
        server: other.server.empty? || other.server == "https://to.sellia.me" ? @server : other.server,
        api_key: other.api_key || @api_key,
        inspector: @inspector.merge(other.inspector),
        tunnels: @tunnels.merge(other.tunnels)
      )
    end

    # Load config from standard paths with merging
    def self.load : Config
      config = Config.new

      # Load in order of increasing priority
      paths = [
        Path.home / ".config" / "sellia" / "sellia.yml",
        Path.home / ".sellia.yml",
        Path.new("sellia.yml"),
      ]

      paths.each do |path|
        if File.exists?(path)
          begin
            file_config = from_yaml(File.read(path))
            config = config.merge(file_config)
          rescue ex
            STDERR.puts "Warning: Failed to parse #{path}: #{ex.message}"
          end
        end
      end

      # Environment variables override (highest priority)
      if env_server = ENV["SELLIA_SERVER"]?
        config.server = env_server
      end
      if env_key = ENV["SELLIA_API_KEY"]?
        config.api_key = env_key
      end

      config
    end
  end
end
