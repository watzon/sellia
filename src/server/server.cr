require "http/server"
require "option_parser"
require "log"
require "./tunnel_registry"
require "./connection_manager"
require "./pending_request"
require "./auth_provider"
require "./rate_limiter"
require "./ws_gateway"
require "./http_ingress"
require "../core/version"

module Sellia::Server
  class Server
    Log = ::Log.for("sellia.server")
    property host : String
    property port : Int32
    property domain : String
    property require_auth : Bool
    property master_key : String?
    property use_https : Bool
    property rate_limiting : Bool

    @tunnel_registry : TunnelRegistry
    @connection_manager : ConnectionManager
    @pending_requests : PendingRequestStore
    @auth_provider : AuthProvider
    @rate_limiter : CompositeRateLimiter
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
      @use_https : Bool = false,
      @rate_limiting : Bool = true,
    )
      @tunnel_registry = TunnelRegistry.new
      @connection_manager = ConnectionManager.new
      @pending_requests = PendingRequestStore.new
      @auth_provider = AuthProvider.new(@require_auth, @master_key)
      @rate_limiter = CompositeRateLimiter.new(enabled: @rate_limiting)

      @ws_gateway = WSGateway.new(
        connection_manager: @connection_manager,
        tunnel_registry: @tunnel_registry,
        auth_provider: @auth_provider,
        pending_requests: @pending_requests,
        rate_limiter: @rate_limiter,
        domain: @domain,
        port: @port,
        use_https: @use_https
      )

      @http_ingress = HTTPIngress.new(
        tunnel_registry: @tunnel_registry,
        connection_manager: @connection_manager,
        pending_requests: @pending_requests,
        rate_limiter: @rate_limiter,
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

      Log.info { "Sellia Server v#{Sellia::VERSION}" }
      Log.info { "Listening on http://#{address}" }
      Log.info { "Domain: #{@domain}" }
      Log.info { "Auth required: #{@require_auth}" }
      Log.info { "Rate limiting: #{@rate_limiting}" }

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

      Log.info { "Shutting down..." }
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
    use_https = ENV["SELLIA_USE_HTTPS"]? == "true"
    rate_limiting = ENV["SELLIA_RATE_LIMITING"]? != "false"

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
      parser.on("--https", "Generate HTTPS URLs for tunnels") { use_https = true }
      parser.on("--no-rate-limit", "Disable rate limiting") { rate_limiting = false }
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
      master_key: master_key,
      use_https: use_https,
      rate_limiting: rate_limiting
    ).start
  end
end
