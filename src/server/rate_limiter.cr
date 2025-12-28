require "mutex"

module Sellia::Server
  # Token bucket rate limiter with sliding window
  class RateLimiter
    struct Bucket
      property tokens : Float64
      property last_update : Time

      def initialize(@tokens : Float64, @last_update : Time = Time.utc)
      end
    end

    struct Config
      property max_tokens : Float64      # Maximum burst capacity
      property refill_rate : Float64     # Tokens per second
      property window : Time::Span       # Window for cleanup

      def initialize(
        @max_tokens : Float64 = 100.0,
        @refill_rate : Float64 = 10.0,
        @window : Time::Span = 1.hour
      )
      end
    end

    property config : Config
    @buckets : Hash(String, Bucket)
    @mutex : Mutex

    def initialize(@config : Config = Config.new)
      @buckets = {} of String => Bucket
      @mutex = Mutex.new
      spawn_cleanup_loop
    end

    # Check if request is allowed and consume a token
    def allow?(key : String, cost : Float64 = 1.0) : Bool
      @mutex.synchronize do
        now = Time.utc
        bucket = @buckets[key]? || Bucket.new(@config.max_tokens, now)

        # Refill tokens based on time elapsed
        elapsed = (now - bucket.last_update).total_seconds
        new_tokens = Math.min(
          @config.max_tokens,
          bucket.tokens + (elapsed * @config.refill_rate)
        )

        if new_tokens >= cost
          @buckets[key] = Bucket.new(new_tokens - cost, now)
          true
        else
          @buckets[key] = Bucket.new(new_tokens, now)
          false
        end
      end
    end

    # Get remaining tokens for a key
    def remaining(key : String) : Float64
      @mutex.synchronize do
        if bucket = @buckets[key]?
          now = Time.utc
          elapsed = (now - bucket.last_update).total_seconds
          Math.min(@config.max_tokens, bucket.tokens + (elapsed * @config.refill_rate))
        else
          @config.max_tokens
        end
      end
    end

    # Reset rate limit for a key
    def reset(key : String)
      @mutex.synchronize { @buckets.delete(key) }
    end

    # Get number of tracked keys
    def size : Int32
      @mutex.synchronize { @buckets.size }
    end

    private def spawn_cleanup_loop
      spawn do
        loop do
          sleep @config.window
          cleanup_stale_buckets
        end
      end
    end

    private def cleanup_stale_buckets
      @mutex.synchronize do
        cutoff = Time.utc - @config.window
        @buckets.reject! { |_, bucket| bucket.last_update < cutoff }
      end
    end
  end

  # Composite rate limiter for multiple limits
  class CompositeRateLimiter
    struct Limits
      property connections_per_ip : RateLimiter::Config
      property tunnels_per_client : RateLimiter::Config
      property requests_per_tunnel : RateLimiter::Config

      def initialize(
        @connections_per_ip : RateLimiter::Config = RateLimiter::Config.new(
          max_tokens: 10.0,     # Max 10 connections burst
          refill_rate: 1.0     # 1 connection per second
        ),
        @tunnels_per_client : RateLimiter::Config = RateLimiter::Config.new(
          max_tokens: 5.0,      # Max 5 tunnels burst
          refill_rate: 0.1     # 1 tunnel per 10 seconds
        ),
        @requests_per_tunnel : RateLimiter::Config = RateLimiter::Config.new(
          max_tokens: 100.0,    # Max 100 requests burst
          refill_rate: 50.0    # 50 requests per second
        )
      )
      end
    end

    property limits : Limits
    property enabled : Bool
    @connection_limiter : RateLimiter
    @tunnel_limiter : RateLimiter
    @request_limiter : RateLimiter

    def initialize(@limits : Limits = Limits.new, @enabled : Bool = true)
      @connection_limiter = RateLimiter.new(@limits.connections_per_ip)
      @tunnel_limiter = RateLimiter.new(@limits.tunnels_per_client)
      @request_limiter = RateLimiter.new(@limits.requests_per_tunnel)
    end

    # Check if a new connection from IP is allowed
    def allow_connection?(ip : String) : Bool
      return true unless @enabled
      @connection_limiter.allow?("conn:#{ip}")
    end

    # Check if creating a new tunnel is allowed
    def allow_tunnel?(client_id : String) : Bool
      return true unless @enabled
      @tunnel_limiter.allow?("tunnel:#{client_id}")
    end

    # Check if a request through tunnel is allowed
    def allow_request?(tunnel_id : String) : Bool
      return true unless @enabled
      @request_limiter.allow?("req:#{tunnel_id}")
    end

    # Get remaining connection tokens for IP
    def remaining_connections(ip : String) : Float64
      @connection_limiter.remaining("conn:#{ip}")
    end

    # Get remaining tunnel tokens for client
    def remaining_tunnels(client_id : String) : Float64
      @tunnel_limiter.remaining("tunnel:#{client_id}")
    end

    # Get remaining request tokens for tunnel
    def remaining_requests(tunnel_id : String) : Float64
      @request_limiter.remaining("req:#{tunnel_id}")
    end

    # Reset limits when client disconnects
    def reset_client(client_id : String)
      @tunnel_limiter.reset("tunnel:#{client_id}")
    end

    # Reset limits when tunnel closes
    def reset_tunnel(tunnel_id : String)
      @request_limiter.reset("req:#{tunnel_id}")
    end
  end
end
