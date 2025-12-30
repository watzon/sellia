require "log"

module Sellia::Server::Storage
  module Migrations
    Log = ::Log.for("sellia.storage.migrations")

    struct Migration
      property version : Int32
      property name : String
      property up_sql : String
      property down_sql : String

      def initialize(@version : Int32, @name : String, @up_sql : String, @down_sql : String)
      end
    end

    MIGRATIONS = [
      Migration.new(
        1,
        "initial_schema",
        <<-SQL,
          CREATE TABLE IF NOT EXISTS schema_migrations (
              version INTEGER PRIMARY KEY,
              applied_at TEXT NOT NULL DEFAULT (datetime('now'))
          );

          CREATE TABLE IF NOT EXISTS reserved_subdomains (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              subdomain TEXT NOT NULL UNIQUE,
              reason TEXT,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              is_default BOOLEAN NOT NULL DEFAULT 0
          );

          CREATE TABLE IF NOT EXISTS api_keys (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              key_hash TEXT NOT NULL UNIQUE,
              key_prefix TEXT NOT NULL,
              name TEXT,
              is_master BOOLEAN NOT NULL DEFAULT 0,
              active BOOLEAN NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              last_used_at TEXT
          );

          CREATE INDEX IF NOT EXISTS idx_api_keys_prefix ON api_keys(key_prefix);
          CREATE INDEX IF NOT EXISTS idx_api_keys_active ON api_keys(active) WHERE active = 1;
        SQL
        <<-SQL
          DROP INDEX IF EXISTS idx_api_keys_active;
          DROP INDEX IF EXISTS idx_api_keys_prefix;
          DROP TABLE IF EXISTS api_keys;
          DROP TABLE IF EXISTS reserved_subdomains;
          DROP TABLE IF EXISTS schema_migrations;
        SQL
      ),
    ]

    # Default reserved subdomains from the original hardcoded list
    DEFAULT_RESERVED_SUBDOMAINS = Set{
      "api", "www", "admin", "app", "dashboard", "console",
      "mail", "smtp", "imap", "pop", "ftp", "ssh", "sftp",
      "cdn", "static", "assets", "media", "images", "files",
      "auth", "login", "oauth", "sso", "account", "accounts",
      "billing", "pay", "payment", "payments", "subscribe",
      "help", "support", "docs", "documentation", "status",
      "blog", "news", "forum", "community", "dev", "developer",
      "test", "staging", "demo", "sandbox", "preview",
      "ws", "wss", "socket", "websocket", "stream",
      "git", "svn", "repo", "registry", "npm", "pypi",
      "internal", "private", "public", "local", "localhost",
      "root", "system", "server", "servers", "node", "nodes",
      "sellia", "tunnel", "tunnels", "proxy",
    }

    def self.current_version : Int32
      begin
        Database.scalar("SELECT COALESCE(MAX(version), 0) FROM schema_migrations").as(Int64).to_i
      rescue
        0
      end
    end

    def self.applied_migrations : Set(Int32)
      migrations = Set(Int32).new
      begin
        Database.query("SELECT version FROM schema_migrations ORDER BY version") do |rs|
          rs.each do
            migrations << rs.read(Int32)
          end
        end
      rescue ex
        # Table doesn't exist yet or other error, return empty set
        Log.debug { "applied_migrations query failed: #{ex.message}" }
        migrations
      end
      migrations
    end

    def self.pending_migrations : Array(Migration)
      applied = applied_migrations
      MIGRATIONS.reject { |m| applied.includes?(m.version) }
    end

    def self.migrate(target : Int32? = nil)
      pending = pending_migrations

      if target
        pending = pending.select { |m| m.version <= target }
      end

      Log.info { "Pending migrations: #{pending.map(&.version)}" }
      return if pending.empty?

      Log.info { "Running #{pending.size} migration(s)" }

      pending.each do |migration|
        Log.info { "Applying migration #{migration.version}: #{migration.name}" }
        # Execute each statement separately (split by semicolon)
        migration.up_sql.split(';').map(&.strip).reject(&.empty?).each do |statement|
          Database.exec(statement)
        end
        Database.exec("INSERT INTO schema_migrations (version) VALUES (?)", migration.version)
      end

      Log.info { "Migrations complete. Current version: #{current_version}" }
    end

    def self.rollback(steps : Int32 = 1)
      current = current_version
      return if current == 0

      target_version = Math.max(0, current - steps)

      # Find migrations to roll back
      to_rollback = MIGRATIONS.select { |m|
        m.version > target_version && m.version <= current
      }.sort_by(&.version).reverse

      return if to_rollback.empty?

      Log.info { "Rolling back #{to_rollback.size} migration(s)" }

      Database.transaction do |conn|
        to_rollback.each do |migration|
          Log.info { "Rolling back migration #{migration.version}: #{migration.name}" }
          conn.exec(migration.down_sql)
          conn.exec("DELETE FROM schema_migrations WHERE version = ?", migration.version)
        end
      end

      Log.info { "Rollback complete. Current version: #{current_version}" }
    end

    # Initialize with default reserved subdomains
    def self.seed_default_reserved_subdomains
      DEFAULT_RESERVED_SUBDOMAINS.each do |subdomain|
        Database.exec("INSERT OR IGNORE INTO reserved_subdomains (subdomain, reason, is_default) VALUES (?, ?, ?)",
          subdomain, "Default reserved subdomain", 1)
      end

      Log.info { "Seeded #{DEFAULT_RESERVED_SUBDOMAINS.size} default reserved subdomains" }
    end

    # Get the default reserved subdomains set
    def self.default_reserved_subdomains : Set(String)
      DEFAULT_RESERVED_SUBDOMAINS
    end
  end
end
