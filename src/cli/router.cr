require "./config"

module Sellia::CLI
  # Convenience alias for RouteConfig in the Config class
  alias RouteConfig = Config::RouteConfig

  class Router
    struct Target
      property host : String
      property port : Int32

      def initialize(@host : String, @port : Int32)
      end
    end

    struct MatchResult
      property target : Target
      property pattern : String

      def initialize(@target : Target, @pattern : String)
      end
    end

    property routes : Array(RouteConfig)
    property default_host : String
    property fallback_port : Int32?

    def initialize(@routes : Array(RouteConfig), @default_host : String, @fallback_port : Int32?)
    end

    def match(path : String) : MatchResult?
      # Try each route in order (first match wins)
      @routes.each do |route|
        if pattern_matches?(route.path, path)
          host = route.host || @default_host
          target = Target.new(host, route.port)
          return MatchResult.new(target, route.path)
        end
      end

      # No route matched - try fallback
      if port = @fallback_port
        target = Target.new(@default_host, port)
        return MatchResult.new(target, "(fallback)")
      end

      # No fallback - return nil
      nil
    end

    private def pattern_matches?(pattern : String, path : String) : Bool
      if pattern.includes?("*")
        # Glob pattern - match prefix before the *
        prefix = pattern.split("*", 2).first
        path.starts_with?(prefix)
      else
        # Exact match
        path == pattern
      end
    end
  end
end
