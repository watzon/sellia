require "../core/sellia"
require "../core/version"

module Sellia::CLI
  def self.run
    puts "Sellia CLI v#{Sellia::VERSION}"
  end
end

Sellia::CLI.run
