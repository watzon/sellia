require "http/server"
require "option_parser"
require "./tunnel_registry"
require "./connection_manager"
require "./pending_request"
require "./auth_provider"
require "./ws_gateway"
require "./http_ingress"
require "../core/version"

module Sellia::Server
  class Server
    property host : String
    property port : Int32
    property domain : String
    property require_auth : Bool
    property master_key : String?
    property use_https : Bool

    @tunnel_registry : TunnelRegistry
    @connection_manager : ConnectionManager
    @pending_requests : PendingRequestStore
    @auth_provider : AuthProvider
    @ws_gateway : WSGateway
    @http_ingress : HTTPIngress
    @server : HTTP::Server?
    @running : Bool = false

    def initialize(
      @host : String = "0.0.0.0",
      @port : Int32 = 3000,
      @domain : String = "localhost",
      @require_auth : Bool = false,
      @master_key : String? = nil,
      @use_https : Bool = false
    )
      @tunnel_registry = TunnelRegistry.new
      @connection_manager = ConnectionManager.new
      @pending_requests = PendingRequestStore.new
      @auth_provider = AuthProvider.new(@require_auth, @master_key)

      @ws_gateway = WSGateway.new(
        connection_manager: @connection_manager,
        tunnel_registry: @tunnel_registry,
        auth_provider: @auth_provider,
        pending_requests: @pending_requests,
        domain: @domain,
        use_https: @use_https
      )

      @http_ingress = HTTPIngress.new(
        tunnel_registry: @tunnel_registry,
        connection_manager: @connection_manager,
        pending_requests: @pending_requests,
        domain: @domain
      )
    end

    def start
      @running = true

      server = HTTP::Server.new do |context|
        handle_request(context)
      end
      @server = server

      # Handle graceful shutdown
      setup_signal_handlers(server)

      address = server.bind_tcp(@host, @port)
      puts "Sellia Server v#{Sellia::VERSION}"
      puts "Listening on http://#{address}"
      puts "Domain: #{@domain}"
      puts "Auth required: #{@require_auth}"
      puts ""
      puts "Press Ctrl+C to stop"

      server.listen
    end

    private def handle_request(context : HTTP::Server::Context)
      path = context.request.path

      # WebSocket upgrade for tunnel clients
      if path == "/ws" && context.request.headers["Upgrade"]?.try(&.downcase) == "websocket"
        ws_handler = HTTP::WebSocketHandler.new do |socket, ctx|
          @ws_gateway.handle(socket)
        end
        ws_handler.call(context)
      else
        # Regular HTTP - proxy to tunnel or serve root
        @http_ingress.handle(context)
      end
    end

    private def setup_signal_handlers(server : HTTP::Server)
      Signal::INT.trap do
        shutdown(server)
      end

      Signal::TERM.trap do
        shutdown(server)
      end
    end

    private def shutdown(server : HTTP::Server)
      return unless @running
      @running = false

      puts "\nShutting down..."
      server.close
      exit 0
    end
  end

  def self.run
    # Load defaults from environment variables
    host = ENV["SELLIA_HOST"]? || "0.0.0.0"
    port = (ENV["SELLIA_PORT"]? || "3000").to_i
    domain = ENV["SELLIA_DOMAIN"]? || "localhost"
    require_auth = ENV["SELLIA_REQUIRE_AUTH"]? == "true"
    master_key = ENV["SELLIA_MASTER_KEY"]?

    # Parse command-line options (override env vars)
    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia-server [options]"

      parser.on("--host HOST", "Host to bind to (default: #{host})") { |h| host = h }
      parser.on("--port PORT", "Port to listen on (default: #{port})") { |p| port = p.to_i }
      parser.on("--domain DOMAIN", "Base domain for subdomains (default: #{domain})") { |d| domain = d }
      parser.on("--require-auth", "Require API key authentication") { require_auth = true }
      parser.on("--master-key KEY", "Master API key (enables auth)") do |k|
        master_key = k
        require_auth = true
      end
      parser.on("-h", "--help", "Show this help") do
        puts parser
        exit 0
      end
      parser.on("-v", "--version", "Show version") do
        puts "Sellia Server v#{Sellia::VERSION}"
        exit 0
      end

      parser.invalid_option do |flag|
        STDERR.puts "Unknown option: #{flag}"
        STDERR.puts parser
        exit 1
      end
    end

    Server.new(
      host: host,
      port: port,
      domain: domain,
      require_auth: require_auth,
      master_key: master_key
    ).start
  end
end
