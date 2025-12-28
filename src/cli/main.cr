require "option_parser"
require "log"
require "./config"
require "./tunnel_client"
require "../core/version"

module Sellia::CLI
  Log = ::Log.for(self)

  def self.run
    # Configure logging
    ::Log.setup_from_env(default_level: :info)

    command = ARGV.shift?

    case command
    when "http"
      run_http_tunnel
    when "start"
      run_start
    when "auth"
      run_auth
    when "version", "-v", "--version"
      puts "Sellia v#{Sellia::VERSION}"
    when "help", "-h", "--help", nil
      print_help
    else
      STDERR.puts "Unknown command: #{command}"
      STDERR.puts "Run 'sellia help' for usage"
      exit 1
    end
  end

  private def self.run_http_tunnel
    config = Config.load

    port = 3000
    subdomain : String? = nil
    auth : String? = nil
    local_host = "localhost"
    server = config.server
    api_key = config.api_key
    inspector_port = config.inspector.port
    open_inspector = config.inspector.open

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia http <port> [options]"

      parser.on("--subdomain NAME", "-s NAME", "Request specific subdomain") { |s| subdomain = s }
      parser.on("--auth USER:PASS", "-a USER:PASS", "Enable basic auth protection") { |a| auth = a }
      parser.on("--host HOST", "-H HOST", "Local host (default: localhost)") { |h| local_host = h }
      parser.on("--server URL", "Tunnel server URL (default: #{server})") { |s| server = s }
      parser.on("--api-key KEY", "-k KEY", "API key for authentication") { |k| api_key = k }
      parser.on("--inspector-port PORT", "-i PORT", "Inspector UI port (default: 4040)") { |p| inspector_port = p.to_i }
      parser.on("--open", "-o", "Open inspector in browser on connect") { open_inspector = true }
      parser.on("-h", "--help", "Show this help") { puts parser; exit 0 }

      parser.unknown_args do |args|
        if args.size > 0
          port = args[0].to_i rescue port
        end
      end

      parser.invalid_option do |flag|
        STDERR.puts "Unknown option: #{flag}"
        STDERR.puts parser
        exit 1
      end
    end

    puts "Sellia v#{Sellia::VERSION}"
    puts "Forwarding to #{local_host}:#{port}"
    puts ""

    client = TunnelClient.new(
      server_url: server,
      local_port: port,
      api_key: api_key,
      local_host: local_host,
      subdomain: subdomain,
      auth: auth
    )

    client.on_connect do |url|
      puts ""
      puts "Public URL: #{url}"
      puts ""
      puts "Press Ctrl+C to stop"
      puts ""

      # Open inspector in browser if requested
      if open_inspector
        spawn do
          open_browser("http://127.0.0.1:#{inspector_port}")
        end
      end
    end

    client.on_request do |req|
      timestamp = Time.local.to_s("%H:%M:%S")
      puts "[#{timestamp}] #{req.method} #{req.path}"
    end

    client.on_error do |error|
      STDERR.puts "Error: #{error}"
    end

    # Handle graceful shutdown
    setup_signal_handlers(client)

    client.start

    # Keep main fiber alive while client is running
    while client.running?
      sleep 1.second
    end
  end

  private def self.run_start
    config = Config.load

    config_file : String? = nil

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia start [options]"

      parser.on("--config FILE", "-c FILE", "Config file path") { |f| config_file = f }
      parser.on("-h", "--help", "Show this help") { puts parser; exit 0 }

      parser.invalid_option do |flag|
        STDERR.puts "Unknown option: #{flag}"
        STDERR.puts parser
        exit 1
      end
    end

    # Load additional config file if specified
    if file = config_file
      if File.exists?(file)
        file_config = Config.from_yaml(File.read(file))
        config = config.merge(file_config)
      else
        STDERR.puts "Config file not found: #{file}"
        exit 1
      end
    end

    if config.tunnels.empty?
      STDERR.puts "No tunnels defined in config"
      STDERR.puts ""
      STDERR.puts "Create a sellia.yml with tunnel definitions:"
      STDERR.puts ""
      STDERR.puts "  tunnels:"
      STDERR.puts "    web:"
      STDERR.puts "      port: 3000"
      STDERR.puts "      subdomain: myapp"
      STDERR.puts "    api:"
      STDERR.puts "      port: 8080"
      STDERR.puts ""
      exit 1
    end

    puts "Sellia v#{Sellia::VERSION}"
    puts "Starting #{config.tunnels.size} tunnel(s)..."
    puts ""

    clients = [] of TunnelClient

    config.tunnels.each do |name, tunnel_config|
      client = TunnelClient.new(
        server_url: config.server,
        local_port: tunnel_config.port,
        api_key: config.api_key,
        local_host: tunnel_config.local_host,
        subdomain: tunnel_config.subdomain,
        auth: tunnel_config.auth
      )

      client.on_connect do |url|
        puts "[#{name}] #{url} -> #{tunnel_config.local_host}:#{tunnel_config.port}"
      end

      client.on_request do |req|
        timestamp = Time.local.to_s("%H:%M:%S")
        puts "[#{timestamp}] [#{name}] #{req.method} #{req.path}"
      end

      client.on_error do |error|
        STDERR.puts "[#{name}] Error: #{error}"
      end

      clients << client
      spawn { client.start }
    end

    puts ""
    puts "Press Ctrl+C to stop all tunnels"

    # Handle graceful shutdown for all clients
    shutdown = false
    Signal::INT.trap do
      unless shutdown
        shutdown = true
        puts "\nShutting down..."
        clients.each(&.stop)
        exit 0
      end
    end

    Signal::TERM.trap do
      unless shutdown
        shutdown = true
        clients.each(&.stop)
        exit 0
      end
    end

    # Keep main fiber alive while any client is running
    loop do
      sleep 1.second
      break unless clients.any?(&.running?)
    end
  end

  private def self.run_auth
    subcommand = ARGV.shift?

    case subcommand
    when "login"
      run_auth_login
    when "logout"
      run_auth_logout
    when "status"
      run_auth_status
    else
      puts "Usage: sellia auth <command>"
      puts ""
      puts "Commands:"
      puts "  login     Save API key for authentication"
      puts "  logout    Remove saved API key"
      puts "  status    Show current authentication status"
    end
  end

  private def self.run_auth_login
    print "API Key: "
    STDOUT.flush

    api_key = gets.try(&.strip)

    if api_key && !api_key.empty?
      config_dir = Path.home / ".config" / "sellia"
      Dir.mkdir_p(config_dir) unless Dir.exists?(config_dir)

      config_path = config_dir / "sellia.yml"

      # Read existing config or create new one
      existing_config = if File.exists?(config_path)
        begin
          Config.from_yaml(File.read(config_path))
        rescue
          Config.new
        end
      else
        Config.new
      end

      # Update API key and write back
      existing_config.api_key = api_key
      File.write(config_path, existing_config.to_yaml)

      puts "API key saved to #{config_path}"
    else
      STDERR.puts "No API key provided"
      exit 1
    end
  end

  private def self.run_auth_logout
    config_path = Path.home / ".config" / "sellia" / "sellia.yml"

    if File.exists?(config_path)
      begin
        config = Config.from_yaml(File.read(config_path))
        config.api_key = nil
        File.write(config_path, config.to_yaml)
        puts "Logged out (API key removed)"
      rescue
        # If we can't parse the file, just delete it
        File.delete(config_path)
        puts "Logged out (config file removed)"
      end
    else
      puts "Not logged in"
    end
  end

  private def self.run_auth_status
    config = Config.load

    if config.api_key
      puts "Status: Logged in"
      puts "Server: #{config.server}"
      # Mask the API key for security
      key = config.api_key.not_nil!
      masked = if key.size > 8
        "#{key[0, 4]}...#{key[-4, 4]}"
      else
        "****"
      end
      puts "API Key: #{masked}"
    else
      puts "Status: Not logged in"
      puts "Server: #{config.server}"
      puts ""
      puts "Run 'sellia auth login' to authenticate"
    end
  end

  private def self.print_help
    puts <<-HELP
    Sellia v#{Sellia::VERSION} - Secure tunnels to localhost

    Usage:
      sellia <command> [options]

    Commands:
      http <port>     Create HTTP tunnel to local port
      start           Start tunnels from config file
      auth            Manage authentication
      version         Show version
      help            Show this help

    Examples:
      sellia http 3000                    Tunnel to localhost:3000
      sellia http 3000 -s myapp           With custom subdomain
      sellia http 3000 --auth user:pass   With basic auth
      sellia start                        Start from sellia.yml
      sellia start -c custom.yml          Start from custom config

    HTTP Options:
      -s, --subdomain NAME    Request specific subdomain
      -a, --auth USER:PASS    Enable basic auth protection
      -H, --host HOST         Local host (default: localhost)
      -k, --api-key KEY       API key for authentication
      -i, --inspector-port    Inspector UI port (default: 4040)
      -o, --open              Open inspector in browser
      --server URL            Tunnel server URL

    Configuration:
      Config files are loaded in order (later overrides earlier):
        ~/.config/sellia/sellia.yml
        ~/.sellia.yml
        ./sellia.yml

      Example sellia.yml:
        server: https://sellia.me
        api_key: your-api-key
        tunnels:
          web:
            port: 3000
            subdomain: myapp
          api:
            port: 8080

    Environment Variables:
      SELLIA_SERVER     Tunnel server URL
      SELLIA_API_KEY    API key for authentication
    HELP
  end

  private def self.setup_signal_handlers(client : TunnelClient)
    shutdown = false

    Signal::INT.trap do
      unless shutdown
        shutdown = true
        puts "\nShutting down..."
        client.stop
        exit 0
      end
    end

    Signal::TERM.trap do
      unless shutdown
        shutdown = true
        client.stop
        exit 0
      end
    end
  end

  private def self.open_browser(url : String)
    {% if flag?(:darwin) %}
      Process.run("open", [url])
    {% elsif flag?(:linux) %}
      Process.run("xdg-open", [url])
    {% elsif flag?(:windows) %}
      Process.run("cmd", ["/c", "start", url])
    {% end %}
  rescue
    # Silently fail if we can't open the browser
  end
end

Sellia::CLI.run
