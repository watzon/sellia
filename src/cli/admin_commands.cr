require "http/client"
require "json"
require "log"
require "colorize"
require "./config"

module Sellia::CLI
  # Admin API client for communicating with the running server
  class AdminClient
    property server_url : String
    property api_key : String

    def initialize(@server_url : String, @api_key : String)
    end

    # Make a GET request to the admin API
    def get(path : String) : HTTP::Client::Response
      HTTP::Client.new(server_url) do |client|
        client.before_request do |request|
          request.headers["Authorization"] = "Bearer #{api_key}"
          request.headers["X-API-Key"] = api_key
        end
        response = client.get(path)
        response
      end
    end

    # Make a POST request to the admin API
    def post(path : String, body : String) : HTTP::Client::Response
      HTTP::Client.new(server_url) do |client|
        client.before_request do |request|
          request.headers["Authorization"] = "Bearer #{api_key}"
          request.headers["X-API-Key"] = api_key
          request.headers["Content-Type"] = "application/json"
        end
        response = client.post(path, body: body)
        response
      end
    end

    # Make a DELETE request to the admin API
    def delete(path : String) : HTTP::Client::Response
      HTTP::Client.new(server_url) do |client|
        client.before_request do |request|
          request.headers["Authorization"] = "Bearer #{api_key}"
          request.headers["X-API-Key"] = api_key
        end
        response = client.delete(path)
        response
      end
    end
  end

  # Create admin client from config
  private def self.create_admin_client(server_url : String? = nil) : AdminClient?
    # Get server URL from arg or config
    url = server_url || Config.load.server

    # Get API key from environment or config
    api_key = ENV["SELLIA_ADMIN_API_KEY"]? || Config.load.api_key

    unless api_key
      STDERR.puts "#{"Error:".colorize(:red).bold} API key required"
      STDERR.puts ""
      STDERR.puts "Set it with:"
      STDERR.puts "  #{"SELLIA_ADMIN_API_KEY".colorize(:cyan)}=your-key sellia admin ..."
      STDERR.puts "  #{"sellia auth login".colorize(:cyan)}"
      exit 1
    end

    AdminClient.new(url, api_key)
  end

  # Handle admin commands
  private def self.run_admin
    subcommand = ARGV.shift?

    case subcommand
    when "reserved"
      run_admin_reserved
    when "api-keys"
      run_admin_api_keys
    when nil
      puts "Usage: sellia admin <command>"
      puts ""
      puts "Commands:"
      puts "  #{"reserved".colorize(:green)}     Manage reserved subdomains"
      puts "  #{"api-keys".colorize(:green)}     Manage API keys"
    else
      STDERR.puts "#{"Error:".colorize(:red).bold} Unknown admin command: #{subcommand}"
      exit 1
    end
  end

  # Reserved subdomain management
  private def self.run_admin_reserved
    action = ARGV.shift?
    server_url = extract_server_flag

    case action
    when "list"
      admin_reserved_list(server_url)
    when "add"
      admin_reserved_add(server_url)
    when "remove", "rm"
      admin_reserved_remove(server_url)
    when nil
      puts "Usage: sellia admin reserved <command> [options]"
      puts ""
      puts "Commands:"
      puts "  #{"list".colorize(:green)}           List all reserved subdomains"
      puts "  #{"add".colorize(:green)} <subdomain> Add a reserved subdomain"
      puts "  #{"remove".colorize(:green)} <subdomain> Remove a reserved subdomain"
      puts ""
      puts "Options:"
      puts "  #{"--server URL".colorize(:cyan)}  Server URL (default: from config)"
    else
      STDERR.puts "#{"Error:".colorize(:red).bold} Unknown action: #{action}"
      exit 1
    end
  end

  private def self.admin_reserved_list(server_url : String?)
    client = create_admin_client(server_url)
    response = client.get("/api/admin/reserved")

    if response.status_code == 401
      STDERR.puts "#{"Error:".colorize(:red).bold} Unauthorized: Admin API key required"
      exit 1
    elsif response.status_code == 503
      STDERR.puts "#{"Error:".colorize(:red).bold} Database not available on server"
      exit 1
    elsif !response.success?
      STDERR.puts "#{"Error:".colorize(:red).bold} #{response.status_code}: #{response.status_message}"
      exit 1
    end

    data = JSON.parse(response.body)
    if data.as_a.empty?
      puts "No reserved subdomains"
      return
    end

    puts "#{"Reserved Subdomains:".colorize(:cyan).bold} (#{data.size})"
    puts ""

    # Calculate max width for alignment
    max_width = data.as_a.map { |r| r["subdomain"].as_s.size }.max? || 10

    data.as_a.each do |r|
      subdomain_plain = r["subdomain"].as_s
      reason = r["reason"]?.try(&.as_s) || ""
      is_default = r["is_default"]?.try(&.as_bool) || false

      flags = [] of String
      flags << "(default)" if is_default

      default_flag = flags.empty? ? "" : (" " + flags.join(" ")).colorize(:dark_gray).to_s

      line = "  #{subdomain_plain.ljust(max_width).colorize(:yellow).to_s}  "
      line += "#{reason.ljust(30)}  " unless reason.empty?
      line += default_flag unless flags.empty?

      puts line
    end
  end

  private def self.admin_reserved_add(server_url : String?)
    subcommand = ARGV.find { |a| !a.starts_with?("--") }
    reason : String? = nil

    # Parse reason flag
    ARGV.each_with_index do |arg, i|
      if arg == "--reason" && i + 1 < ARGV.size
        reason = ARGV[i + 1]
      end
    end

    unless subcommand
      STDERR.puts "#{"Error:".colorize(:red).bold} Missing subdomain"
      STDERR.puts ""
      STDERR.puts "Usage: sellia admin reserved add <subdomain> [--reason REASON]"
      exit 1
    end

    client = create_admin_client(server_url)

    body = {
      subdomain: subcommand,
      reason:    reason,
    }.to_json

    response = client.post("/api/admin/reserved", body)

    if response.status_code == 401
      STDERR.puts "#{"Error:".colorize(:red).bold} Unauthorized: Admin API key required"
      exit 1
    elsif response.status_code == 409
      STDERR.puts "#{"Error:".colorize(:red).bold} Subdomain '#{subcommand}' is already reserved"
      exit 1
    elsif response.status_code == 400
      data = JSON.parse(response.body)
      error_msg = data["error"]?.try(&.as_s) || "Invalid request"
      STDERR.puts "#{"Error:".colorize(:red).bold} #{error_msg}"
      exit 1
    elsif response.status_code == 503
      STDERR.puts "#{"Error:".colorize(:red).bold} Database not available on server"
      exit 1
    elsif response.status_code == 201
      puts "#{"✓".colorize(:green)} Reserved subdomain '#{subcommand.colorize(:yellow)}'"
      if reason
        puts "  Reason: #{reason}"
      end
    else
      STDERR.puts "#{"Error:".colorize(:red).bold} #{response.status_code}: #{response.status_message}"
      exit 1
    end
  end

  private def self.admin_reserved_remove(server_url : String?)
    subcommand = ARGV.find { |a| !a.starts_with?("--") }

    unless subcommand
      STDERR.puts "#{"Error:".colorize(:red).bold} Missing subdomain"
      STDERR.puts ""
      STDERR.puts "Usage: sellia admin reserved remove <subdomain>"
      exit 1
    end

    client = create_admin_client(server_url)
    response = client.delete("/api/admin/reserved/#{subcommand}")

    if response.status_code == 401
      STDERR.puts "#{"Error:".colorize(:red).bold} Unauthorized: Admin API key required"
      exit 1
    elsif response.status_code == 403
      STDERR.puts "#{"Error:".colorize(:red).bold} Cannot remove default reserved subdomain"
      exit 1
    elsif response.status_code == 404
      STDERR.puts "#{"Error:".colorize(:red).bold} Reserved subdomain '#{subcommand}' not found"
      exit 1
    elsif response.status_code == 503
      STDERR.puts "#{"Error:".colorize(:red).bold} Database not available on server"
      exit 1
    elsif response.status_code == 200
      puts "#{"✓".colorize(:green)} Removed reserved subdomain '#{subcommand.colorize(:yellow)}'"
    else
      STDERR.puts "#{"Error:".colorize(:red).bold} #{response.status_code}: #{response.status_message}"
      exit 1
    end
  end

  # API key management
  private def self.run_admin_api_keys
    action = ARGV.shift?
    server_url = extract_server_flag

    case action
    when "list"
      admin_api_keys_list(server_url)
    when "create"
      admin_api_keys_create(server_url)
    when "revoke", "rm"
      admin_api_keys_revoke(server_url)
    when nil
      puts "Usage: sellia admin api-keys <command> [options]"
      puts ""
      puts "Commands:"
      puts "  #{"list".colorize(:green)}            List all API keys"
      puts "  #{"create".colorize(:green)}          Create a new API key"
      puts "  #{"revoke".colorize(:green)} <prefix> Revoke an API key"
      puts ""
      puts "Options:"
      puts "  #{"--server URL".colorize(:cyan)}   Server URL (default: from config)"
      puts ""
      puts "Create options:"
      puts "  #{"--name NAME".colorize(:cyan)}    Friendly name for the key"
      puts "  #{"--master".colorize(:cyan)}       Create master key (admin access)"
    else
      STDERR.puts "#{"Error:".colorize(:red).bold} Unknown action: #{action}"
      exit 1
    end
  end

  private def self.admin_api_keys_list(server_url : String?)
    client = create_admin_client(server_url)
    response = client.get("/api/admin/api-keys")

    if response.status_code == 401
      STDERR.puts "#{"Error:".colorize(:red).bold} Unauthorized: Admin API key required"
      exit 1
    elsif response.status_code == 503
      STDERR.puts "#{"Error:".colorize(:red).bold} Database not available on server"
      exit 1
    elsif !response.success?
      STDERR.puts "#{"Error:".colorize(:red).bold} #{response.status_code}: #{response.status_message}"
      exit 1
    end

    data = JSON.parse(response.body)
    if data.as_a.empty?
      puts "No API keys found"
      return
    end

    puts "#{"API Keys:".colorize(:cyan).bold} (#{data.size})"
    puts ""

    # Calculate max width for alignment
    max_width = data.as_a.map { |k| k["key_prefix"]?.try(&.as_s.size) || 0 }.max? || 10

    data.as_a.each do |k|
      prefix = k["key_prefix"]?.try(&.as_s) || "unknown"
      name = k["name"]?.try(&.as_s) || ""
      is_master = k["is_master"]?.try(&.as_bool) || false
      active = k["active"]?.try(&.as_bool) || true
      created_at = k["created_at"]?.try(&.as_s) || ""

      flags = [] of String
      flags << "(master)" if is_master
      flags << "(revoked)" unless active

      # Build flags string with appropriate colors
      flags_str = flags.empty? ? "" : " " + flags.map_with_index do |f, i|
        if f == "(master)"
          f.colorize(:red).bold.to_s
        else
          f.colorize(:dark_gray).to_s
        end
      end.join(" ")

      line = "  #{prefix.ljust(max_width)}  "
      line += "#{name.ljust(20)}  " unless name.empty?
      line += flags_str unless flags.empty?

      puts line
      puts "    Created: #{Time.parse_iso8601(created_at).to_s("%Y-%m-%d %H:%M")}" unless created_at.empty?
    end
  end

  private def self.admin_api_keys_create(server_url : String?)
    name : String? = nil
    is_master = false

    # Parse flags
    ARGV.each_with_index do |arg, i|
      if arg == "--name" && i + 1 < ARGV.size
        name = ARGV[i + 1]
      elsif arg == "--master"
        is_master = true
      end
    end

    client = create_admin_client(server_url)

    body = {
      name:      name,
      is_master: is_master,
    }.to_json

    response = client.post("/api/admin/api-keys", body)

    if response.status_code == 401
      STDERR.puts "#{"Error:".colorize(:red).bold} Unauthorized: Admin API key required"
      exit 1
    elsif response.status_code == 503
      STDERR.puts "#{"Error:".colorize(:red).bold} Database not available on server"
      exit 1
    elsif response.status_code == 201
      data = JSON.parse(response.body)
      key = data["key"]?.try(&.as_s) || "unknown"
      prefix = data["key_prefix"]?.try(&.as_s) || "unknown"

      puts "#{"✓".colorize(:green)} API key created"
      puts ""
      puts "  #{"Key:".colorize(:cyan).bold} #{key.colorize(:yellow)}"
      puts "  #{"Prefix:".colorize(:white).bold} #{prefix}"
      if name
        puts "  #{"Name:".colorize(:white).bold} #{name}"
      end
      if is_master
        puts "  #{"Type:".colorize(:white).bold} Master (admin access)"
      end
      puts ""
      puts "#{"Save this key now - it won't be shown again!".colorize(:red).bold}"
    else
      STDERR.puts "#{"Error:".colorize(:red).bold} #{response.status_code}: #{response.status_message}"
      STDERR.puts response.body
      exit 1
    end
  end

  private def self.admin_api_keys_revoke(server_url : String?)
    prefix = ARGV.find { |a| !a.starts_with?("--") }

    unless prefix
      STDERR.puts "#{"Error:".colorize(:red).bold} Missing key prefix"
      STDERR.puts ""
      STDERR.puts "Usage: sellia admin api-keys revoke <key-prefix>"
      exit 1
    end

    client = create_admin_client(server_url)
    response = client.delete("/api/admin/api-keys/#{prefix}")

    if response.status_code == 401
      STDERR.puts "#{"Error:".colorize(:red).bold} Unauthorized: Admin API key required"
      exit 1
    elsif response.status_code == 404
      STDERR.puts "#{"Error:".colorize(:red).bold} API key '#{prefix}' not found"
      exit 1
    elsif response.status_code == 503
      STDERR.puts "#{"Error:".colorize(:red).bold} Database not available on server"
      exit 1
    elsif response.status_code == 200
      puts "#{"✓".colorize(:green)} API key '#{prefix.colorize(:yellow)}' revoked"
    else
      STDERR.puts "#{"Error:".colorize(:red).bold} #{response.status_code}: #{response.status_message}"
      exit 1
    end
  end

  # Extract --server flag from ARGV and return the URL
  private def self.extract_server_flag : String?
    server_url = nil
    ARGV.each_with_index do |arg, i|
      if arg == "--server" && i + 1 < ARGV.size
        server_url = ARGV[i + 1]
      end
    end
    server_url
  end
end
