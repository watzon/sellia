require "../core/sellia"
require "../core/version"

module Sellia::Server
  def self.run
    puts "Sellia Server v#{Sellia::VERSION}"
    puts "Starting server..."
  end
end

Sellia::Server.run
