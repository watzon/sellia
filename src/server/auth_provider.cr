require "digest/sha256"
require "./storage/storage"

module Sellia::Server
  # Simple auth provider - validates API keys
  # In Tier 1, we support a single master key or no auth (for self-hosted)
  # With database enabled, also validates against stored API keys
  class AuthProvider
    property require_auth : Bool
    property master_key : String?
    property use_database : Bool

    def initialize(@require_auth : Bool = false, @master_key : String? = nil, @use_database : Bool = false)
    end

    def validate(api_key : String) : Bool
      return true unless @require_auth
      return false if api_key.empty?

      # Check database first if enabled
      if @use_database && Storage::Database.instance?
        if found = Storage::Repositories::ApiKeys.validate(api_key)
          return true
        end
      end

      # Fallback to master key
      if master = @master_key
        api_key == master
      else
        # No master key configured - accept any non-empty key
        true
      end
    end

    def account_id_for(api_key : String) : String
      # Try to get account_id from database
      if @use_database && Storage::Database.instance?
        if key_record = Storage::Repositories::ApiKeys.validate(api_key)
          return key_record.id.to_s
        end
      end

      # Simple implementation - hash the key
      Digest::SHA256.hexdigest(api_key)[0, 16]
    end
  end
end
