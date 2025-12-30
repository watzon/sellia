require "http/server"
require "option_parser"
require "log"
require "./tunnel_registry"
require "./connection_manager"
require "./pending_request"
require "./pending_websocket"
require "./auth_provider"
require "./rate_limiter"
require "./ws_gateway"
require "./http_ingress"
require "./admin_api"
require "./storage/storage"
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
    property landing_enabled : Bool
    property db_path : String
    property db_enabled : Bool

    @tunnel_registry : TunnelRegistry
    @connection_manager : ConnectionManager
    @pending_requests : PendingRequestStore
    @pending_websockets : PendingWebSocketStore
    @auth_provider : AuthProvider
    @rate_limiter : CompositeRateLimiter
    @ws_gateway : WSGateway
    @http_ingress : HTTPIngress
    @admin_api : AdminAPI
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
      @landing_enabled : Bool = true,
      db_path : String? = nil,
      @db_enabled : Bool = true,
    )
      # Set default db path if not provided
      @db_path = db_path || File.join(Path.home, ".sellia", "sellia.db")
      # Initialize database FIRST (before other components that need it)
      initialize_database(@db_path, @db_enabled)

      # Load reserved subdomains from database or use defaults
      reserved_subdomains = load_reserved_subdomains

      @tunnel_registry = TunnelRegistry.new(reserved_subdomains)
      @connection_manager = ConnectionManager.new
      @pending_requests = PendingRequestStore.new
      @pending_websockets = PendingWebSocketStore.new
      @auth_provider = AuthProvider.new(@require_auth, @master_key, use_database: database_available?)
      @rate_limiter = CompositeRateLimiter.new(enabled: @rate_limiting)
      @admin_api = AdminAPI.new(@auth_provider, @tunnel_registry)

      @ws_gateway = WSGateway.new(
        connection_manager: @connection_manager,
        tunnel_registry: @tunnel_registry,
        auth_provider: @auth_provider,
        pending_requests: @pending_requests,
        pending_websockets: @pending_websockets,
        rate_limiter: @rate_limiter,
        domain: @domain,
        port: @port,
        use_https: @use_https
      )

      @http_ingress = HTTPIngress.new(
        tunnel_registry: @tunnel_registry,
        connection_manager: @connection_manager,
        pending_requests: @pending_requests,
        pending_websockets: @pending_websockets,
        rate_limiter: @rate_limiter,
        domain: @domain,
        landing_enabled: @landing_enabled
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

    # Initialize database with migrations and seed data
    private def initialize_database(path : String, enabled : Bool)
      return unless enabled
      return if path.empty? || path == ":none:"

      begin
        # Ensure parent directory exists
        dir = File.dirname(path)
        Dir.mkdir_p(dir) if !Dir.exists?(dir)

        # Open database
        Storage::Database.open(path)

        # Run migrations
        Storage::Migrations.migrate

        # Seed default reserved subdomains
        Storage::Migrations.seed_default_reserved_subdomains

        Log.info { "Database initialized at #{path}" }
      rescue ex : Exception
        Log.error { "Failed to initialize database: #{ex.message}" }
        # Continue without database - use in-memory defaults
        Storage::Database.close rescue nil
      end
    end

    # Check if database is available
    private def database_available? : Bool
      Storage::Database.instance? != nil
    end

    # Load reserved subdomains from database or use defaults
    private def load_reserved_subdomains : Set(String)
      if database_available?
        begin
          return Storage::Repositories::ReservedSubdomains.to_set
        rescue ex : Exception
          Log.warn { "Failed to load reserved subdomains from database: #{ex.message}" }
        end
      end

      # Fallback to defaults
      Storage::Migrations.default_reserved_subdomains
    end

    private def handle_request(context : HTTP::Server::Context)
      path = context.request.path

      # Admin API endpoints
      if path.starts_with?("/api/admin/")
        @admin_api.handle(context)
        return
      end

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

      # Close database connection
      Storage::Database.close

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
    landing_enabled = ENV["SELLIA_DISABLE_LANDING"]? != "true"
    db_path = ENV["SELLIA_DB_PATH"]? || File.join(Path.home, ".sellia", "sellia.db")
    db_enabled = ENV["SELLIA_NO_DB"]? != "true" && ENV["SELLIA_NO_DB"]? != "1"

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
      parser.on("--no-landing", "Disable the landing page") { landing_enabled = false }
      parser.on("--db-path PATH", "Path to SQLite database") { |p| db_path = p }
      parser.on("--no-db", "Disable database (use in-memory defaults)") { db_enabled = false }
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
      rate_limiting: rate_limiting,
      landing_enabled: landing_enabled,
      db_path: db_path,
      db_enabled: db_enabled
    ).start
  end
end
