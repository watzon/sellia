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
    port = 3000
    domain : String? = nil

    acme_enabled = false
    acme_email = "admin@example.com"
    acme_test = false

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia serve [options]"
      parser.on("--host HOST", "Host to bind to (default: 0.0.0.0)") { |h| host = h }
      parser.on("--port PORT", "Port to listen on (default: 3000)") { |p| port = p.to_i }
      parser.on("--domain DOMAIN", "Base domain for subdomains (optional, defaults to request Host)") { |d| domain = d }
      parser.on("--acme", "Enable ACME (Let's Encrypt) SSL") { acme_enabled = true }
      parser.on("--acme-email EMAIL", "Email for ACME registration") { |e| acme_email = e }
      parser.on("--acme-test", "Use Let's Encrypt Staging environment (for testing)") { acme_test = true }
      parser.on("-h", "--help", "Show this help") { puts parser; exit }
    end

    Server.new(host, port, domain, acme_enabled, acme_email, acme_test).start
  end

  def self.run_tunnel
    server_host = "https://sellia.me"
    server_port = 443
    local_port = 3000
    subdomain = nil
    local_host = "localhost"

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia tunnel [options]"
      parser.on("-h HOST", "--host HOST", "Upstream server host (default: https://sellia.me)") { |h| server_host = h }
      parser.on("--server-port PORT", "Upstream server port (default: 443)") { |p| server_port = p.to_i }
      parser.on("-p PORT", "--port PORT", "Local port to forward") { |p| local_port = p.to_i }
      parser.on("-s SUBDOMAIN", "--subdomain SUBDOMAIN", "Request this subdomain") { |s| subdomain = s }
      parser.on("-l HOST", "--local-host HOST", "Override Host header to this value (default: localhost)") { |h| local_host = h }
      parser.on("--help", "Show this help") { puts parser; exit }
    end

    Client.new(server_host, server_port, local_port, subdomain, local_host).start
  end
end
