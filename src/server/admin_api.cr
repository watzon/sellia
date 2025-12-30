require "http/server"
require "json"
require "log"
require "random/secure"
require "./storage/storage"
require "./auth_provider"
require "./tunnel_registry"

module Sellia::Server
  # Admin API endpoints for managing reserved subdomains and API keys
  # Requires admin authentication (API key with is_master = true)
  class AdminAPI
    Log = ::Log.for("sellia.server.admin_api")

    property auth_provider : AuthProvider
    property tunnel_registry : TunnelRegistry?

    def initialize(@auth_provider : AuthProvider, @tunnel_registry : TunnelRegistry? = nil)
    end

    # Check if request is authenticated with an admin key
    private def admin_authenticated?(context : HTTP::Server::Context) : Bool
      auth_header = context.request.headers["Authorization"]?

      # Support Bearer token
      if auth_header && auth_header.starts_with?("Bearer ")
        api_key = auth_header[7..-1]
        return is_admin_key?(api_key)
      end

      # Support X-API-Key header
      api_key = context.request.headers["X-API-Key"]?
      return is_admin_key?(api_key) if api_key

      false
    end

    # Check if the API key is an admin key (is_master = true)
    private def is_admin_key?(api_key : String) : Bool
      # Check database for admin status
      if Storage::Database.instance?
        key_hash = Storage::Models::ApiKey.hash_key(api_key)
        if key_record = Storage::Repositories::ApiKeys.find_by_hash(key_hash)
          return key_record.is_master
        end
        return false
      end

      # Fallback to master key only
      if master = @auth_provider.master_key
        return api_key == master
      end

      false
    end

    # Extract API key from request
    private def extract_api_key(context : HTTP::Server::Context) : String?
      auth_header = context.request.headers["Authorization"]?
      if auth_header && auth_header.starts_with?("Bearer ")
        return auth_header[7..-1]
      end

      context.request.headers["X-API-Key"]?
    end

    # Send JSON response
    private def json_response(context : HTTP::Server::Context, status : HTTP::Status, data : NamedTuple)
      context.response.status = status
      context.response.content_type = "application/json"
      data.to_json(context.response)
    end

    private def json_response(context : HTTP::Server::Context, status : HTTP::Status, data : Hash | Array)
      context.response.status = status
      context.response.content_type = "application/json"
      data.to_json(context.response)
    end

    private def error_response(context : HTTP::Server::Context, message : String, status : HTTP::Status = HTTP::Status::BAD_REQUEST)
      json_response(context, status, {error: message})
    end

    # Handle admin API requests
    def handle(context : HTTP::Server::Context)
      # All admin endpoints require authentication
      unless admin_authenticated?(context)
        return error_response(context, "Unauthorized: Admin API key required", HTTP::Status::UNAUTHORIZED)
      end

      path = context.request.path

      # Reserved subdomain endpoints
      if path == "/api/admin/reserved" && context.request.method == "GET"
        handle_list_reserved(context)
      elsif path == "/api/admin/reserved" && context.request.method == "POST"
        handle_add_reserved(context)
      elsif path.starts_with?("/api/admin/reserved/") && context.request.method == "DELETE"
        handle_remove_reserved(context)
        # API key endpoints
      elsif path == "/api/admin/api-keys" && context.request.method == "GET"
        handle_list_api_keys(context)
      elsif path == "/api/admin/api-keys" && context.request.method == "POST"
        handle_create_api_key(context)
      elsif path.starts_with?("/api/admin/api-keys/") && context.request.method == "DELETE"
        handle_revoke_api_key(context)
      else
        error_response(context, "Not found", HTTP::Status::NOT_FOUND)
      end
    end

    # GET /api/admin/reserved - List all reserved subdomains
    private def handle_list_reserved(context : HTTP::Server::Context)
      unless Storage::Database.instance?
        return error_response(context, "Database not available", HTTP::Status::SERVICE_UNAVAILABLE)
      end

      reserved = Storage::Repositories::ReservedSubdomains.all
      data = reserved.map do |r|
        {
          subdomain:  r.subdomain,
          reason:     r.reason,
          is_default: r.is_default,
          created_at: r.created_at.to_s("%Y-%m-%dT%H:%M:%S.%6%z"),
        }
      end

      json_response(context, HTTP::Status::OK, data)
    end

    # POST /api/admin/reserved - Add a reserved subdomain
    private def handle_add_reserved(context : HTTP::Server::Context)
      unless Storage::Database.instance?
        return error_response(context, "Database not available", HTTP::Status::SERVICE_UNAVAILABLE)
      end

      # Parse request body
      body = context.request.body
      return error_response(context, "Missing request body") unless body

      begin
        json = JSON.parse(body.gets_to_end)
        subdomain = json["subdomain"].as_s?
        reason = json["reason"]?.try(&.as_s?)

        unless subdomain
          return error_response(context, "Missing 'subdomain' field")
        end

        # Validate subdomain format
        if subdomain.size < 3
          return error_response(context, "Subdomain must be at least 3 characters")
        end
        if subdomain.size > 63
          return error_response(context, "Subdomain must be at most 63 characters")
        end
        unless subdomain.matches?(/\A[a-z0-9][a-z0-9-]*[a-z0-9]\z/i)
          return error_response(context, "Subdomain can only contain lowercase letters, numbers, and hyphens")
        end

        # Check if already exists
        if Storage::Repositories::ReservedSubdomains.exists?(subdomain)
          return error_response(context, "Subdomain already reserved", HTTP::Status::CONFLICT)
        end

        # Create reserved subdomain
        Storage::Repositories::ReservedSubdomains.create(subdomain, reason, is_default: false)
        refresh_reserved_subdomains

        json_response(context, HTTP::Status::CREATED, {
          subdomain:  subdomain,
          reason:     reason,
          is_default: false,
          created_at: Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%6%z"),
        })
      rescue ex : JSON::ParseException
        error_response(context, "Invalid JSON: #{ex.message}")
      rescue ex : Exception
        error_response(context, "Error: #{ex.message}", HTTP::Status::INTERNAL_SERVER_ERROR)
      end
    end

    # DELETE /api/admin/reserved/:subdomain - Remove a reserved subdomain
    private def handle_remove_reserved(context : HTTP::Server::Context)
      unless Storage::Database.instance?
        return error_response(context, "Database not available", HTTP::Status::SERVICE_UNAVAILABLE)
      end

      subdomain = context.request.path.split("/").last

      # Don't allow removing default reserved subdomains
      reserved = Storage::Repositories::ReservedSubdomains.all.find { |r| r.subdomain == subdomain }
      if reserved && reserved.is_default
        return error_response(context, "Cannot remove default reserved subdomain", HTTP::Status::FORBIDDEN)
      end

      if Storage::Repositories::ReservedSubdomains.delete(subdomain)
        refresh_reserved_subdomains
        json_response(context, HTTP::Status::OK, {
          message: "Reserved subdomain '#{subdomain}' removed",
        })
      else
        error_response(context, "Reserved subdomain not found", HTTP::Status::NOT_FOUND)
      end
    end

    # GET /api/admin/api-keys - List all API keys
    private def handle_list_api_keys(context : HTTP::Server::Context)
      unless Storage::Database.instance?
        return error_response(context, "Database not available", HTTP::Status::SERVICE_UNAVAILABLE)
      end

      api_keys = Storage::Repositories::ApiKeys.all
      data = api_keys.map do |k|
        {
          id:           k.id,
          key_prefix:   k.key_prefix,
          name:         k.name,
          is_master:    k.is_master,
          active:       k.active,
          created_at:   k.created_at.to_s("%Y-%m-%dT%H:%M:%S.%6%z"),
          last_used_at: k.last_used_at.try(&.to_s("%Y-%m-%dT%H:%M:%S.%6%z")),
        }
      end

      json_response(context, HTTP::Status::OK, data)
    end

    # POST /api/admin/api-keys - Create a new API key
    private def handle_create_api_key(context : HTTP::Server::Context)
      unless Storage::Database.instance?
        return error_response(context, "Database not available", HTTP::Status::SERVICE_UNAVAILABLE)
      end

      # Parse request body
      body = context.request.body
      return error_response(context, "Missing request body") unless body

      begin
        json = JSON.parse(body.gets_to_end)
        name = json["name"]?.try(&.as_s?)
        is_master = json["is_master"]?.try(&.as_bool?) || false

        # Generate a random API key
        new_key = Random::Secure.hex(32)

        # Create in database
        key_record = Storage::Repositories::ApiKeys.create(new_key, name, is_master: is_master)

        # Return the full key (only shown once)
        json_response(context, HTTP::Status::CREATED, {
          id:         key_record.id,
          key:        new_key, # Only shown on creation
          key_prefix: key_record.key_prefix,
          name:       name,
          is_master:  is_master,
          active:     true,
          created_at: Time.utc.to_s("%Y-%m-%dT%H:%M:%S.%6%z"),
        })
      rescue ex : JSON::ParseException
        error_response(context, "Invalid JSON: #{ex.message}")
      rescue ex : Exception
        error_response(context, "Error: #{ex.message}", HTTP::Status::INTERNAL_SERVER_ERROR)
      end
    end

    # DELETE /api/admin/api-keys/:prefix - Revoke an API key
    private def handle_revoke_api_key(context : HTTP::Server::Context)
      unless Storage::Database.instance?
        return error_response(context, "Database not available", HTTP::Status::SERVICE_UNAVAILABLE)
      end

      prefix = context.request.path.split("/").last

      if Storage::Repositories::ApiKeys.revoke(prefix)
        json_response(context, HTTP::Status::OK, {
          message: "API key '#{prefix}' revoked",
        })
      else
        error_response(context, "API key not found", HTTP::Status::NOT_FOUND)
      end
    end

    private def refresh_reserved_subdomains : Nil
      return unless registry = @tunnel_registry
      return unless Storage::Database.instance?

      begin
        registry.reload_reserved_subdomains!(Storage::Repositories::ReservedSubdomains.to_set)
      rescue ex : Exception
        Log.warn { "Failed to refresh reserved subdomains: #{ex.message}" }
      end
    end
  end
end
