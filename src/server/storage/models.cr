require "openssl"

module Sellia::Server::Storage::Models
  def self.parse_sqlite_time(value : String) : Time
    if value.includes?('T')
      Time.parse_iso8601(value)
    else
      Time.parse(value, "%F %T", Time::Location::UTC)
    end
  end

  struct ReservedSubdomain
    property id : Int64?
    property subdomain : String
    property reason : String?
    property created_at : Time
    property is_default : Bool

    def initialize(
      @subdomain : String,
      @reason : String? = nil,
      @created_at : Time = Time.utc,
      @is_default : Bool = false,
      @id : Int64? = nil,
    )
    end

    def self.from_rs(rs : DB::ResultSet) : self
      new(
        id: rs.read(Int64?),
        subdomain: rs.read(String),
        reason: rs.read(String?),
        created_at: Models.parse_sqlite_time(rs.read(String)),
        is_default: rs.read(Bool)
      )
    end
  end

  struct ApiKey
    property id : Int64?
    property key_hash : String
    property key_prefix : String
    property name : String?
    property is_master : Bool
    property active : Bool
    property created_at : Time
    property last_used_at : Time?

    def initialize(
      @key_hash : String,
      @key_prefix : String,
      @name : String? = nil,
      @is_master : Bool = false,
      @active : Bool = true,
      @created_at : Time = Time.utc,
      @last_used_at : Time? = nil,
      @id : Int64? = nil,
    )
    end

    def self.from_rs(rs : DB::ResultSet) : self
      new(
        id: rs.read(Int64?),
        key_hash: rs.read(String),
        key_prefix: rs.read(String),
        name: rs.read(String?),
        is_master: rs.read(Bool),
        active: rs.read(Bool),
        created_at: Models.parse_sqlite_time(rs.read(String)),
        last_used_at: rs.read(String?).try { |s| Models.parse_sqlite_time(s) }
      )
    end

    # Helper to create hash from plaintext key
    def self.hash_key(plaintext : String) : String
      OpenSSL::Digest.new("SHA256").update(plaintext).final.hexstring
    end

    # Helper to extract prefix (first 8 chars for identification)
    def self.extract_prefix(plaintext : String) : String
      plaintext[0, Math.min(8, plaintext.size)]
    end
  end
end
