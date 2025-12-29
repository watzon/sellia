require "option_parser"
require "log"
require "colorize"
require "./config"
require "./tunnel_client"
require "./request_store"
require "./inspector"
require "./updater"
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
    when "update"
      run_update
    when "version", "-v", "--version"
      puts "#{"Sellia".colorize(:cyan).bold} v#{Sellia::VERSION}"
    when "help", "-h", "--help", nil
      print_help
    else
      STDERR.puts "#{"Error:".colorize(:red).bold} Unknown command: #{command}"
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
    no_inspector = false

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia http <port> [options]"

      parser.on("--subdomain NAME", "-s NAME", "Request specific subdomain") { |s| subdomain = s }
      parser.on("--auth USER:PASS", "-a USER:PASS", "Enable basic auth protection") { |a| auth = a }
      parser.on("--host HOST", "-H HOST", "Local host (default: localhost)") { |h| local_host = h }
      parser.on("--server URL", "Tunnel server URL (default: #{server})") { |s| server = s }
      parser.on("--api-key KEY", "-k KEY", "API key for authentication") { |k| api_key = k }
      parser.on("--inspector-port PORT", "-i PORT", "Inspector UI port (default: 4040)") { |p| inspector_port = p.to_i }
      parser.on("--open", "-o", "Open inspector in browser on connect") { open_inspector = true }
      parser.on("--no-inspector", "Disable the request inspector") { no_inspector = true }
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

    puts "#{"Sellia".colorize(:cyan).bold} v#{Sellia::VERSION}"
    puts "Forwarding to #{"#{local_host}:#{port}".colorize(:yellow)}"
    puts ""

    # Create request store and inspector unless disabled
    request_store : RequestStore? = nil
    inspector : Inspector? = nil

    unless no_inspector
      request_store = RequestStore.new
      inspector = Inspector.new(inspector_port, request_store)

      # Start inspector in background
      spawn do
        inspector.not_nil!.start
      end

      # Give inspector time to bind
      sleep 0.1.seconds
    end

    client = TunnelClient.new(
      server_url: server,
      local_port: port,
      api_key: api_key,
      local_host: local_host,
      subdomain: subdomain,
      auth: auth,
      request_store: request_store
    )

    client.on_connect do |url|
      puts ""
      puts "#{"Public URL:".colorize(:green).bold} #{url.colorize(:green).underline}"
      unless no_inspector
        puts "#{"Inspector:".colorize(:magenta).bold}  #{"http://127.0.0.1:#{inspector_port}".colorize(:magenta).underline}"
      end
      puts ""
      puts "Press #{"Ctrl+C".colorize(:yellow)} to stop"
      puts ""

      # Open inspector in browser if requested
      if open_inspector && !no_inspector
        spawn do
          open_browser("http://127.0.0.1:#{inspector_port}")
        end
      end
    end

    client.on_request do |req|
      timestamp = Time.local.to_s("%H:%M:%S")
      method_color = case req.method
                     when "GET"    then :green
                     when "POST"   then :blue
                     when "PUT"    then :yellow
                     when "PATCH"  then :yellow
                     when "DELETE" then :red
                     else               :white
                     end
      puts "[#{timestamp.colorize(:dark_gray)}] #{req.method.colorize(method_color).bold} #{req.path}"
    end

    client.on_error do |error|
      STDERR.puts "#{"Error:".colorize(:red).bold} #{error}"
    end

    # Handle graceful shutdown
    setup_signal_handlers(client, inspector)

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
      STDERR.puts "#{"Error:".colorize(:red).bold} No tunnels defined in config"
      STDERR.puts ""
      STDERR.puts "Create a sellia.yml with tunnel definitions:"
      STDERR.puts ""
      STDERR.puts "  #{"tunnels:".colorize(:cyan)}"
      STDERR.puts "    #{"web:".colorize(:yellow)}"
      STDERR.puts "      port: 3000"
      STDERR.puts "      subdomain: myapp"
      STDERR.puts "    #{"api:".colorize(:yellow)}"
      STDERR.puts "      port: 8080"
      STDERR.puts ""
      exit 1
    end

    puts "#{"Sellia".colorize(:cyan).bold} v#{Sellia::VERSION}"
    puts "Starting #{config.tunnels.size.to_s.colorize(:green)} tunnel(s)..."
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
        puts "[#{name.colorize(:cyan)}] #{url.colorize(:green).underline} -> #{"#{tunnel_config.local_host}:#{tunnel_config.port}".colorize(:yellow)}"
      end

      client.on_request do |req|
        timestamp = Time.local.to_s("%H:%M:%S")
        method_color = case req.method
                       when "GET"    then :green
                       when "POST"   then :blue
                       when "PUT"    then :yellow
                       when "PATCH"  then :yellow
                       when "DELETE" then :red
                       else               :white
                       end
        puts "[#{timestamp.colorize(:dark_gray)}] [#{name.colorize(:cyan)}] #{req.method.colorize(method_color).bold} #{req.path}"
      end

      client.on_error do |error|
        STDERR.puts "[#{name.colorize(:cyan)}] #{"Error:".colorize(:red).bold} #{error}"
      end

      clients << client
      spawn { client.start }
    end

    puts ""
    puts "Press #{"Ctrl+C".colorize(:yellow)} to stop all tunnels"

    # Handle graceful shutdown for all clients
    shutdown = false
    Signal::INT.trap do
      unless shutdown
        shutdown = true
        puts "\n#{"Shutting down...".colorize(:yellow)}"
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

      puts "#{"✓".colorize(:green)} API key saved to #{config_path.to_s.colorize(:dark_gray)}"
    else
      STDERR.puts "#{"Error:".colorize(:red).bold} No API key provided"
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
        puts "#{"✓".colorize(:green)} Logged out (API key removed)"
      rescue
        # If we can't parse the file, just delete it
        File.delete(config_path)
        puts "#{"✓".colorize(:green)} Logged out (config file removed)"
      end
    else
      puts "#{"Not logged in".colorize(:yellow)}"
    end
  end

  private def self.run_auth_status
    config = Config.load

    if config.api_key
      puts "#{"Status:".colorize(:white).bold} #{"Logged in".colorize(:green)}"
      puts "#{"Server:".colorize(:white).bold} #{config.server}"
      # Mask the API key for security
      key = config.api_key.not_nil!
      masked = if key.size > 8
                 "#{key[0, 4]}...#{key[-4, 4]}"
               else
                 "****"
               end
      puts "#{"API Key:".colorize(:white).bold} #{masked.colorize(:dark_gray)}"
    else
      puts "#{"Status:".colorize(:white).bold} #{"Not logged in".colorize(:yellow)}"
      puts "#{"Server:".colorize(:white).bold} #{config.server}"
      puts ""
      puts "Run #{"sellia auth login".colorize(:cyan)} to authenticate"
    end
  end

  private def self.run_update
    check_only = false
    force = false
    target_version : String? = nil

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia update [options]"

      parser.on("--check", "-c", "Check for updates without installing") { check_only = true }
      parser.on("--force", "-f", "Force reinstall even if up-to-date") { force = true }
      parser.on("--version VER", "-v VER", "Update to specific version") { |v| target_version = v }
      parser.on("-h", "--help", "Show this help") { puts parser; exit 0 }

      parser.invalid_option do |flag|
        STDERR.puts "Unknown option: #{flag}"
        STDERR.puts parser
        exit 1
      end
    end

    updater = Updater.new(
      check_only: check_only,
      force: force,
      target_version: target_version
    )

    success = updater.run
    exit(success ? 0 : 1)
  end

  private def self.print_help
    puts "#{"Sellia".colorize(:cyan).bold} v#{Sellia::VERSION} - Secure tunnels to localhost"
    puts ""
    puts "#{"Usage:".colorize(:yellow).bold}"
    puts "  sellia <command> [options]"
    puts ""
    puts "#{"Commands:".colorize(:yellow).bold}"
    puts "  #{"http".colorize(:green)} <port>     Create HTTP tunnel to local port"
    puts "  #{"start".colorize(:green)}           Start tunnels from config file"
    puts "  #{"auth".colorize(:green)}            Manage authentication"
    puts "  #{"update".colorize(:green)}          Update to latest version"
    puts "  #{"version".colorize(:green)}         Show version"
    puts "  #{"help".colorize(:green)}            Show this help"
    puts ""
    puts "#{"Examples:".colorize(:yellow).bold}"
    puts "  sellia http 3000                    Tunnel to localhost:3000"
    puts "  sellia http 3000 -s myapp           With custom subdomain"
    puts "  sellia http 3000 --auth user:pass   With basic auth"
    puts "  sellia start                        Start from sellia.yml"
    puts "  sellia start -c custom.yml          Start from custom config"
    puts ""
    puts "#{"HTTP Options:".colorize(:yellow).bold}"
    puts "  #{"-s, --subdomain".colorize(:cyan)} NAME    Request specific subdomain"
    puts "  #{"-a, --auth".colorize(:cyan)} USER:PASS    Enable basic auth protection"
    puts "  #{"-H, --host".colorize(:cyan)} HOST         Local host (default: localhost)"
    puts "  #{"-k, --api-key".colorize(:cyan)} KEY       API key for authentication"
    puts "  #{"-i, --inspector-port".colorize(:cyan)}    Inspector UI port (default: 4040)"
    puts "  #{"-o, --open".colorize(:cyan)}              Open inspector in browser"
    puts "  #{"--no-inspector".colorize(:cyan)}          Disable the request inspector"
    puts "  #{"--server".colorize(:cyan)} URL            Tunnel server URL"
    puts ""
    puts "#{"Configuration:".colorize(:yellow).bold}"
    puts "  Config files are loaded in order (later overrides earlier):"
    puts "    ~/.config/sellia/sellia.yml"
    puts "    ~/.sellia.yml"
    puts "    ./sellia.yml"
    puts ""
    puts "  Example sellia.yml:"
    puts "    #{"server:".colorize(:cyan)} https://sellia.me"
    puts "    #{"api_key:".colorize(:cyan)} your-api-key"
    puts "    #{"tunnels:".colorize(:cyan)}"
    puts "      #{"web:".colorize(:yellow)}"
    puts "        port: 3000"
    puts "        subdomain: myapp"
    puts "      #{"api:".colorize(:yellow)}"
    puts "        port: 8080"
    puts ""
    puts "#{"Environment Variables:".colorize(:yellow).bold}"
    puts "  #{"SELLIA_SERVER".colorize(:cyan)}     Tunnel server URL"
    puts "  #{"SELLIA_API_KEY".colorize(:cyan)}    API key for authentication"
  end

  private def self.setup_signal_handlers(client : TunnelClient, inspector : Inspector? = nil)
    shutdown = false

    Signal::INT.trap do
      unless shutdown
        shutdown = true
        puts "\n#{"Shutting down...".colorize(:yellow)}"
        inspector.try(&.stop)
        client.stop
        exit 0
      end
    end

    Signal::TERM.trap do
      unless shutdown
        shutdown = true
        inspector.try(&.stop)
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
