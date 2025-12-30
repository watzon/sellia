require "./models"

module Sellia::Server::Storage
  module Repositories
    Log = ::Log.for("sellia.storage.repositories")

    # Reserved subdomain repository
    module ReservedSubdomains
      def self.all : Array(Models::ReservedSubdomain)
        results = [] of Models::ReservedSubdomain
        Database.query("SELECT * FROM reserved_subdomains ORDER BY subdomain") do |rs|
          rs.each do
            results << Models::ReservedSubdomain.from_rs(rs)
          end
        end
        results
      end

      def self.exists?(subdomain : String) : Bool
        begin
          !Database.scalar(
            "SELECT 1 FROM reserved_subdomains WHERE subdomain = ? LIMIT 1",
            subdomain.downcase
          ).nil?
        rescue ex : DB::NoResultsError
          false
        end
      end

      def self.create(subdomain : String, reason : String? = nil, is_default : Bool = false) : Models::ReservedSubdomain
        Database.exec(
          "INSERT INTO reserved_subdomains (subdomain, reason, is_default) VALUES (?, ?, ?)",
          subdomain.downcase, reason, is_default
        )
        Models::ReservedSubdomain.new(
          subdomain: subdomain.downcase,
          reason: reason,
          is_default: is_default
        )
      end

      def self.delete(subdomain : String) : Bool
        affected = Database.exec(
          "DELETE FROM reserved_subdomains WHERE subdomain = ?",
          subdomain.downcase
        )
        affected.rows_affected > 0
      end

      def self.to_set : Set(String)
        result = Set(String).new
        Database.query("SELECT subdomain FROM reserved_subdomains") do |rs|
          rs.each { result << rs.read(String) }
        end
        result
      end
    end

    # API key repository
    module ApiKeys
      def self.find_by_hash(key_hash : String) : Models::ApiKey?
        Database.query(
          "SELECT * FROM api_keys WHERE key_hash = ? AND active = 1",
          key_hash
        ) do |rs|
          return Models::ApiKey.from_rs(rs) if rs.move_next
        end
        nil
      end

      def self.find_by_prefix(prefix : String) : Array(Models::ApiKey)
        results = [] of Models::ApiKey
        Database.query(
          "SELECT * FROM api_keys WHERE key_prefix LIKE ? || '%' ORDER BY created_at DESC",
          prefix
        ) do |rs|
          rs.each do
            results << Models::ApiKey.from_rs(rs)
          end
        end
        results
      end

      def self.find_by_id(id : Int64) : Models::ApiKey?
        Database.query(
          "SELECT * FROM api_keys WHERE id = ?",
          id
        ) do |rs|
          return Models::ApiKey.from_rs(rs) if rs.move_next
        end
        nil
      end

      def self.validate(plaintext_key : String) : Models::ApiKey?
        return nil if plaintext_key.empty?
        key_hash = Models::ApiKey.hash_key(plaintext_key)

        if api_key = find_by_hash(key_hash)
          # Update last_used_at
          if id = api_key.id
            Database.exec(
              "UPDATE api_keys SET last_used_at = datetime('now') WHERE id = ?",
              id
            )
            api_key.last_used_at = Time.utc
          end
          api_key
        else
          nil
        end
      end

      def self.create(
        plaintext_key : String,
        name : String? = nil,
        is_master : Bool = false,
      ) : Models::ApiKey
        key_hash = Models::ApiKey.hash_key(plaintext_key)
        key_prefix = Models::ApiKey.extract_prefix(plaintext_key)

        Database.exec(
          "INSERT INTO api_keys (key_hash, key_prefix, name, is_master) VALUES (?, ?, ?, ?)",
          key_hash, key_prefix, name, is_master
        )

        Models::ApiKey.new(
          key_hash: key_hash,
          key_prefix: key_prefix,
          name: name,
          is_master: is_master
        )
      end

      def self.revoke(prefix : String) : Bool
        affected = Database.exec(
          "UPDATE api_keys SET active = 0 WHERE key_prefix = ?",
          prefix
        )
        affected.rows_affected > 0
      end

      def self.count_active : Int32
        Database.scalar("SELECT COUNT(*) FROM api_keys WHERE active = 1").as(Int64).to_i
      end

      def self.all : Array(Models::ApiKey)
        results = [] of Models::ApiKey
        Database.query("SELECT * FROM api_keys ORDER BY created_at DESC") do |rs|
          rs.each do
            results << Models::ApiKey.from_rs(rs)
          end
        end
        results
      end
    end
  end
end
