require "db"
require "sqlite3"

module Sellia::Server::Storage
  class Database
    Log = ::Log.for("sellia.storage.database")

    @@instance : DB::Database?

    def self.open(path : String | Path = ":memory:")
      db_path = path.to_s

      # For in-memory database, reuse existing instance (tests share same DB)
      if db_path == ":memory:"
        if @@instance
          return @@instance.not_nil!
        end
        # Use shared cache mode with pool size 1 so all queries use the same connection
        # Need to URL-encode the path since :memory: gets parsed as a port
        @@instance = DB.open("sqlite3://%3Amemory%3A?mode=memory&cache=shared&max_pool_size=1")
        Log.info { "Database opened: in-memory (shared, pool=1)" }
        return @@instance.not_nil!
      end

      # For file-based databases, use singleton pattern
      return @@instance.not_nil! if @@instance

      # Configure SQLite for production
      # WAL mode: Better concurrency, readers don't block writers
      # synchronous=NORMAL: Faster writes with acceptable safety
      # max_pool_size=1 ensures all queries use the same connection (important for tests)
      connection_string = "sqlite3://#{db_path}?journal_mode=WAL&synchronous=NORMAL&cache_size=-64000&foreign_keys=true&max_pool_size=1"
      @@instance = DB.open(connection_string)
      Log.info { "Database opened: #{db_path}" }

      @@instance.not_nil!
    end

    def self.instance : DB::Database
      @@instance || raise "Database not opened. Call Database.open first."
    end

    def self.instance? : DB::Database?
      @@instance
    end

    def self.close
      if db = @@instance
        db.close
        @@instance = nil
        Log.info { "Database closed" }
      end
    end

    # Reset the database singleton (useful for tests)
    def self.reset!
      if db = @@instance
        db.close
        @@instance = nil
      end
    end

    # For queries that return single values
    def self.scalar(query : String, *args) : DB::Any
      instance.scalar(query, *args)
    end

    # For queries that return no rows (INSERT, UPDATE, DELETE)
    def self.exec(query : String, *args) : DB::ExecResult
      instance.exec(query, *args)
    end

    # For queries that return rows
    def self.query(query : String, *args, &block : DB::ResultSet -> Nil)
      instance.query(query, *args) do |rs|
        yield rs
      end
    end

    # Transaction support
    def self.transaction(&block)
      instance.transaction do |tx|
        yield tx.connection
      end
    end
  end
end
