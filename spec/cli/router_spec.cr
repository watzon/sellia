require "../spec_helper"
require "../../src/cli/router"
require "../../src/cli/config"

# Convenience alias
alias RouteConfig = Sellia::CLI::RouteConfig

describe Sellia::CLI::Router do
  describe "#match" do
    it "matches exact path without glob" do
      routes = [
        RouteConfig.new("/health", 3000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 8080)

      result = router.match("/health")
      result.should_not be_nil
      result.not_nil!.target.port.should eq 3000
    end

    it "matches path with glob suffix" do
      routes = [
        RouteConfig.new("/api/*", 4000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 8080)

      result = router.match("/api/users")
      result.should_not be_nil
      result.not_nil!.target.port.should eq 4000
      result.not_nil!.pattern.should eq "/api/*"
    end

    it "returns first matching route" do
      routes = [
        RouteConfig.new("/api/*", 4000),
        RouteConfig.new("/api/admin/*", 5000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 8080)

      result = router.match("/api/admin/users")
      result.should_not be_nil
      result.not_nil!.target.port.should eq 4000 # First match wins
    end

    it "uses fallback when no route matches" do
      routes = [
        RouteConfig.new("/api/*", 4000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 8080)

      result = router.match("/other/path")
      result.should_not be_nil
      result.not_nil!.target.port.should eq 8080
      result.not_nil!.pattern.should eq "(fallback)"
    end

    it "returns nil when no match and no fallback" do
      routes = [
        RouteConfig.new("/api/*", 4000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", nil)

      result = router.match("/other/path")
      result.should be_nil
    end

    it "uses route host when specified" do
      routes = [
        RouteConfig.new("/api/*", 4000, "api-service"),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 8080)

      result = router.match("/api/users")
      result.should_not be_nil
      result.not_nil!.target.host.should eq "api-service"
    end

    it "uses default host when route host not specified" do
      routes = [
        RouteConfig.new("/api/*", 4000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 8080)

      result = router.match("/api/users")
      result.should_not be_nil
      result.not_nil!.target.host.should eq "localhost"
    end
  end
end
