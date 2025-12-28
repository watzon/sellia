require "log"
require "./server"

# Configure logging
Log.setup do |c|
  backend = Log::IOBackend.new(formatter: Log::ShortFormat)
  c.bind "*", :info, backend

  # Debug level for verbose output (can be enabled via env)
  if ENV["SELLIA_DEBUG"]? == "true"
    c.bind "sellia.*", :debug, backend
  end
end

Sellia::Server.run
