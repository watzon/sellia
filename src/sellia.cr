require "option_parser"
require "./sellia/server"
require "./sellia/client"

module Sellia
  VERSION = "0.1.0"

  def self.run
    command = ARGV.shift?

    case command
    when "serve"
      run_serve
    when "tunnel"
      run_tunnel
    else
      puts "Usage: sellia [serve|tunnel] [options]"
      exit 1
    end
  end

  def self.run_serve
    host = "0.0.0.0"
    port = 8080
    domain = "localhost"

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia serve [options]"
      parser.on("--host HOST", "Host to bind to (default: 0.0.0.0)") { |h| host = h }
      parser.on("--port PORT", "Port to listen on (default: 8080)") { |p| port = p.to_i }
      parser.on("--domain DOMAIN", "Base domain for subdomains (default: localhost)") { |d| domain = d }
      parser.on("-h", "--help", "Show this help") { puts parser; exit }
    end

    Server.new(host, port, domain).start
  end

  def self.run_tunnel
    server_host = "localhost"
    server_port = 8080
    local_port = 3000
    subdomain = nil
    local_host = "localhost"

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia tunnel [options]"
      parser.on("-h HOST", "--host HOST", "Upstream server host (default: localhost)") { |h| server_host = h }
      parser.on("--server-port PORT", "Upstream server port (default: 8080)") { |p| server_port = p.to_i }
      parser.on("-p PORT", "--port PORT", "Local port to forward") { |p| local_port = p.to_i }
      parser.on("-s SUBDOMAIN", "--subdomain SUBDOMAIN", "Request this subdomain") { |s| subdomain = s }
      parser.on("-l HOST", "--local-host HOST", "Override Host header to this value (default: localhost)") { |h| local_host = h }
      parser.on("--help", "Show this help") { puts parser; exit }
    end

    Client.new(server_host, server_port, local_port, subdomain, local_host).start
  end
end
