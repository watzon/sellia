require "../spec_helper"
require "../../src/server/rate_limiter"

describe Sellia::Server::RateLimiter do
  it "consumes tokens and blocks when empty" do
    config = Sellia::Server::RateLimiter::Config.new(max_tokens: 2.0, refill_rate: 0.0)
    limiter = Sellia::Server::RateLimiter.new(config)

    limiter.allow?("a").should eq(true)
    limiter.allow?("a").should eq(true)
    limiter.allow?("a").should eq(false)
  end

  it "refills tokens over time" do
    config = Sellia::Server::RateLimiter::Config.new(max_tokens: 1.0, refill_rate: 100.0)
    limiter = Sellia::Server::RateLimiter.new(config)

    limiter.allow?("a").should eq(true)
    limiter.allow?("a").should eq(false)

    sleep 0.05.seconds
    limiter.allow?("a").should eq(true)
  end
end

describe Sellia::Server::CompositeRateLimiter do
  it "disables limits when disabled" do
    limiter = Sellia::Server::CompositeRateLimiter.new(enabled: false)

    limiter.allow_connection?("1.2.3.4").should eq(true)
    limiter.allow_tunnel?("client").should eq(true)
    limiter.allow_request?("tunnel").should eq(true)
  end

  it "applies limits per category" do
    limits = Sellia::Server::CompositeRateLimiter::Limits.new(
      connections_per_ip: Sellia::Server::RateLimiter::Config.new(max_tokens: 1.0, refill_rate: 0.0),
      tunnels_per_client: Sellia::Server::RateLimiter::Config.new(max_tokens: 1.0, refill_rate: 0.0),
      requests_per_tunnel: Sellia::Server::RateLimiter::Config.new(max_tokens: 1.0, refill_rate: 0.0),
    )
    limiter = Sellia::Server::CompositeRateLimiter.new(limits, enabled: true)

    limiter.allow_connection?("1.2.3.4").should eq(true)
    limiter.allow_connection?("1.2.3.4").should eq(false)

    limiter.allow_tunnel?("client").should eq(true)
    limiter.allow_tunnel?("client").should eq(false)

    limiter.allow_request?("tunnel").should eq(true)
    limiter.allow_request?("tunnel").should eq(false)
  end
end
