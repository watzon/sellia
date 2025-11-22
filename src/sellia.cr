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
    host = "localhost"
    port = 8080

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia serve [options]"
      parser.on("--host HOST", "Host to bind to") { |h| host = h }
      parser.on("--port PORT", "Port to listen on") { |p| port = p.to_i }
      parser.on("-h", "--help", "Show this help") { puts parser; exit }
    end

    Server.new(host, port).start
  end

  def self.run_tunnel
    via = "localhost"
    via_port = 8080
    local_port = 3000
    subdomain = "test"
    auto_tls = false

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia tunnel [options]"
      parser.on("--via HOST", "Server host") { |h| via = h }
      parser.on("--via-port PORT", "Server port") { |p| via_port = p.to_i }
      parser.on("--port PORT", "Local port to forward") { |p| local_port = p.to_i }
      parser.on("--subdomain SUBDOMAIN", "Subdomain to use") { |s| subdomain = s }
      parser.on("--auto-tls", "Enable Auto TLS (stubbed)") { auto_tls = true }
      parser.on("-h", "--help", "Show this help") { puts parser; exit }
    end

    Client.new(via, via_port, local_port, subdomain).start
  end
end
