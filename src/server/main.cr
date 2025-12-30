require "log"
require "./server"

# Configure logging from environment (LOG_LEVEL, CRYSTAL_LOG_LEVEL, or CRYSTAL_LOG_SOURCES)
# Falls back to info level if not specified
# Set LOG_LEVEL=DEBUG to enable debug logging
Log.setup_from_env(default_level: :warn)

Sellia::Server.run
