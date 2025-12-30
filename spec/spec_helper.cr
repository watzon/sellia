require "spec"
require "log"
require "msgpack"
require "../src/sellia"
require "../src/server/storage/storage"

# Reduce log noise during specs unless overridden by env.
Log.setup_from_env(default_level: :warn)

# Initialize shared test database once before all tests
# This is done at the top level to ensure it runs before any tests
module SpecHelper
  @@db_initialized = false

  def self.ensure_test_db
    unless @@db_initialized
      # Use a temporary file database instead of :memory: for better connection pool support
      # The shared cache mode with :memory: has issues with connection pooling
      db_path = "/tmp/sellia_test_#{Process.pid}.db"
      Sellia::Server::Storage::Database.open(db_path)
      Sellia::Server::Storage::Migrations.migrate
      Sellia::Server::Storage::Migrations.seed_default_reserved_subdomains
      @@db_initialized = true

      # Clean up temp file on exit
      at_exit { File.delete(db_path) if File.exists?(db_path) }
    end
  end

  def self.reset_db(keep_defaults : Bool = true)
    return unless Sellia::Server::Storage::Database.instance?

    # Keep defaults by removing only non-default rows for a lighter reset.
    if keep_defaults
      Sellia::Server::Storage::Database.exec("DELETE FROM reserved_subdomains WHERE is_default = 0")
    else
      Sellia::Server::Storage::Database.exec("DELETE FROM reserved_subdomains")
    end

    Sellia::Server::Storage::Database.exec("DELETE FROM api_keys")

    if keep_defaults
      default_count = Sellia::Server::Storage::Database.scalar(
        "SELECT COUNT(*) FROM reserved_subdomains WHERE is_default = 1"
      ).as(Int64)
      Sellia::Server::Storage::Migrations.seed_default_reserved_subdomains if default_count == 0
    end
  end
end

# Initialize database immediately (before any tests run)
SpecHelper.ensure_test_db

Spec.before_each do
  SpecHelper.reset_db
end
