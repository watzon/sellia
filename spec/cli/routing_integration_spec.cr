require "../spec_helper"
require "../../src/cli/config"
require "../../src/cli/router"

describe "Path-based routing integration" do
  it "routes requests to different backends based on path" do
    routes = [
      Sellia::CLI::RouteConfig.new("/api/*", 4000, "api"),
      Sellia::CLI::RouteConfig.new("/static/*", 8080),
    ]
    router = Sellia::CLI::Router.new(routes, "localhost", 3000)

    # API route
    api_match = router.match("/api/users")
    api_match.should_not be_nil
    api_match.not_nil!.target.host.should eq "api"
    api_match.not_nil!.target.port.should eq 4000

    # Static route (uses default host)
    static_match = router.match("/static/app.js")
    static_match.should_not be_nil
    static_match.not_nil!.target.host.should eq "localhost"
    static_match.not_nil!.target.port.should eq 8080

    # Fallback
    other_match = router.match("/index.html")
    other_match.should_not be_nil
    other_match.not_nil!.target.port.should eq 3000
    other_match.not_nil!.pattern.should eq "(fallback)"
  end

  it "parses routes from YAML config" do
    yaml = <<-YAML
    tunnels:
      web:
        type: http
        subdomain: myapp
        port: 3000
        local_host: localhost
        routes:
          - path: /api/*
            port: 4000
            host: api
          - path: /static/*
            port: 8080
    YAML

    config = Sellia::CLI::Config.from_yaml(yaml)
    tunnel = config.tunnels["web"]
    tunnel.routes.size.should eq 2
    tunnel.routes[0].path.should eq "/api/*"
    tunnel.routes[0].port.should eq 4000
    tunnel.routes[0].host.should eq "api"
    tunnel.routes[1].path.should eq "/static/*"
    tunnel.routes[1].port.should eq 8080
    tunnel.routes[1].host.should be_nil
  end

  describe "route matching order" do
    it "uses first match when multiple routes match" do
      routes = [
        Sellia::CLI::RouteConfig.new("/api/*", 4000),
        Sellia::CLI::RouteConfig.new("/api/admin/*", 5000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 3000)

      # Both routes match /api/admin/users, but first match wins
      result = router.match("/api/admin/users")
      result.should_not be_nil
      result.not_nil!.target.port.should eq 4000
      result.not_nil!.pattern.should eq "/api/*"
    end

    it "respects order when more specific route is first" do
      routes = [
        Sellia::CLI::RouteConfig.new("/api/admin/*", 5000),
        Sellia::CLI::RouteConfig.new("/api/*", 4000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 3000)

      # More specific route matches first
      admin_result = router.match("/api/admin/users")
      admin_result.should_not be_nil
      admin_result.not_nil!.target.port.should eq 5000

      # General route matches non-admin paths
      api_result = router.match("/api/users")
      api_result.should_not be_nil
      api_result.not_nil!.target.port.should eq 4000
    end
  end

  describe "integration with TunnelConfig" do
    it "creates router from tunnel config routes" do
      yaml = <<-YAML
      tunnels:
        microservices:
          type: http
          subdomain: app
          port: 5000
          routes:
            - path: /users/*
              port: 3001
              host: user-service
            - path: /products/*
              port: 3002
              host: product-service
            - path: /orders/*
              port: 3003
      YAML

      config = Sellia::CLI::Config.from_yaml(yaml)
      tunnel = config.tunnels["microservices"]

      # Create router from tunnel config
      router = Sellia::CLI::Router.new(
        tunnel.routes,
        tunnel.local_host,
        tunnel.port > 0 ? tunnel.port : nil
      )

      # Users route
      users = router.match("/users/123")
      users.should_not be_nil
      users.not_nil!.target.host.should eq "user-service"
      users.not_nil!.target.port.should eq 3001

      # Products route
      products = router.match("/products/456")
      products.should_not be_nil
      products.not_nil!.target.host.should eq "product-service"
      products.not_nil!.target.port.should eq 3002

      # Orders route (uses default host from tunnel config)
      orders = router.match("/orders/789")
      orders.should_not be_nil
      orders.not_nil!.target.host.should eq "localhost"
      orders.not_nil!.target.port.should eq 3003

      # Fallback to tunnel port
      fallback = router.match("/health")
      fallback.should_not be_nil
      fallback.not_nil!.target.port.should eq 5000
      fallback.not_nil!.pattern.should eq "(fallback)"
    end

    it "handles tunnel config with empty routes" do
      yaml = <<-YAML
      tunnels:
        simple:
          type: http
          port: 8080
      YAML

      config = Sellia::CLI::Config.from_yaml(yaml)
      tunnel = config.tunnels["simple"]

      tunnel.routes.should be_empty

      # Router with no routes should always use fallback
      router = Sellia::CLI::Router.new(
        tunnel.routes,
        tunnel.local_host,
        tunnel.port
      )

      result = router.match("/any/path")
      result.should_not be_nil
      result.not_nil!.target.port.should eq 8080
      result.not_nil!.pattern.should eq "(fallback)"
    end
  end

  describe "path matching patterns" do
    it "matches exact paths" do
      routes = [
        Sellia::CLI::RouteConfig.new("/health", 9000),
        Sellia::CLI::RouteConfig.new("/api/*", 4000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 3000)

      # Exact match
      health = router.match("/health")
      health.should_not be_nil
      health.not_nil!.target.port.should eq 9000

      # Exact path doesn't match subpaths
      health_check = router.match("/health/check")
      health_check.should_not be_nil
      health_check.not_nil!.pattern.should eq "(fallback)"
    end

    it "matches glob patterns at any depth" do
      routes = [
        Sellia::CLI::RouteConfig.new("/api/*", 4000),
      ]
      router = Sellia::CLI::Router.new(routes, "localhost", 3000)

      # Single level
      router.match("/api/users").not_nil!.target.port.should eq 4000

      # Multiple levels
      router.match("/api/users/123/profile").not_nil!.target.port.should eq 4000

      # With query strings
      router.match("/api/search?q=test").not_nil!.target.port.should eq 4000
    end
  end
end
