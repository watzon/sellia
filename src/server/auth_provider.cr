require "digest/sha256"

module Sellia::Server
  # Simple auth provider - validates API keys
  # In Tier 1, we support a single master key or no auth (for self-hosted)
  class AuthProvider
    property require_auth : Bool
    property master_key : String?

    def initialize(@require_auth : Bool = false, @master_key : String? = nil)
    end

    def validate(api_key : String) : Bool
      return true unless @require_auth
      return false if api_key.empty?

      if master = @master_key
        api_key == master
      else
        # No master key configured - accept any non-empty key
        true
      end
    end

    def account_id_for(api_key : String) : String
      # Simple implementation - hash the key
      Digest::SHA256.hexdigest(api_key)[0, 16]
    end
  end
end
