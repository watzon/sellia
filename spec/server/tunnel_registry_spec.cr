require "../spec_helper"
require "../../src/server/tunnel_registry"

describe Sellia::Server::TunnelRegistry do
  describe "#register" do
    it "registers a tunnel with a subdomain" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456"
      )

      registry.register(tunnel)
      registry.find_by_subdomain("myapp").should eq(tunnel)
    end

    it "returns nil for unknown subdomain" do
      registry = Sellia::Server::TunnelRegistry.new
      registry.find_by_subdomain("unknown").should be_nil
    end
  end

  describe "#unregister" do
    it "removes a tunnel" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456"
      )

      registry.register(tunnel)
      registry.unregister(tunnel.id)
      registry.find_by_subdomain("myapp").should be_nil
    end
  end

  describe "#generate_subdomain" do
    it "generates a unique subdomain" do
      registry = Sellia::Server::TunnelRegistry.new
      sub1 = registry.generate_subdomain
      sub2 = registry.generate_subdomain

      sub1.should_not eq(sub2)
      sub1.size.should be >= 6
    end
  end

  describe "#find_by_id" do
    it "finds tunnel by ID" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456"
      )

      registry.register(tunnel)
      registry.find_by_id("tun-123").should eq(tunnel)
    end

    it "returns nil for unknown ID" do
      registry = Sellia::Server::TunnelRegistry.new
      registry.find_by_id("unknown").should be_nil
    end
  end

  describe "#find_by_client" do
    it "finds all tunnels for a client" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel1 = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-1",
        subdomain: "app1",
        client_id: "client-456"
      )
      tunnel2 = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-2",
        subdomain: "app2",
        client_id: "client-456"
      )

      registry.register(tunnel1)
      registry.register(tunnel2)

      tunnels = registry.find_by_client("client-456")
      tunnels.size.should eq(2)
    end

    it "returns empty array for unknown client" do
      registry = Sellia::Server::TunnelRegistry.new
      registry.find_by_client("unknown").should eq([] of Sellia::Server::TunnelRegistry::Tunnel)
    end
  end

  describe "#subdomain_available?" do
    it "returns true for available subdomain" do
      registry = Sellia::Server::TunnelRegistry.new
      registry.subdomain_available?("myapp").should be_true
    end

    it "returns false for taken subdomain" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456"
      )

      registry.register(tunnel)
      registry.subdomain_available?("myapp").should be_false
    end
  end

  describe "#size" do
    it "returns the number of registered tunnels" do
      registry = Sellia::Server::TunnelRegistry.new
      registry.size.should eq(0)

      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456"
      )

      registry.register(tunnel)
      registry.size.should eq(1)
    end
  end

  describe "#unregister_client" do
    it "removes all tunnels for a client" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel1 = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-1",
        subdomain: "app1",
        client_id: "client-456"
      )
      tunnel2 = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-2",
        subdomain: "app2",
        client_id: "client-456"
      )

      registry.register(tunnel1)
      registry.register(tunnel2)

      removed = registry.unregister_client("client-456")
      removed.size.should eq(2)
      registry.size.should eq(0)
      registry.find_by_subdomain("app1").should be_nil
      registry.find_by_subdomain("app2").should be_nil
    end
  end

  describe "#validate_subdomain" do
    it "accepts valid subdomains" do
      registry = Sellia::Server::TunnelRegistry.new

      %w[myapp my-app app123 a1b2c3 abc].each do |subdomain|
        result = registry.validate_subdomain(subdomain)
        result.valid.should be_true, "Expected '#{subdomain}' to be valid"
      end
    end

    it "rejects subdomains that are too short" do
      registry = Sellia::Server::TunnelRegistry.new
      result = registry.validate_subdomain("ab")
      result.valid.should be_false
      result.error.not_nil!.should contain("at least 3 characters")
    end

    it "rejects subdomains that are too long" do
      registry = Sellia::Server::TunnelRegistry.new
      long_name = "a" * 64
      result = registry.validate_subdomain(long_name)
      result.valid.should be_false
      result.error.not_nil!.should contain("at most 63 characters")
    end

    it "rejects subdomains starting with hyphen" do
      registry = Sellia::Server::TunnelRegistry.new
      result = registry.validate_subdomain("-myapp")
      result.valid.should be_false
      result.error.not_nil!.should contain("hyphen")
    end

    it "rejects subdomains ending with hyphen" do
      registry = Sellia::Server::TunnelRegistry.new
      result = registry.validate_subdomain("myapp-")
      result.valid.should be_false
      result.error.not_nil!.should contain("hyphen")
    end

    it "rejects subdomains with invalid characters" do
      registry = Sellia::Server::TunnelRegistry.new
      %w[my_app my.app my@app my!app my\ app].each do |subdomain|
        result = registry.validate_subdomain(subdomain)
        result.valid.should be_false, "Expected '#{subdomain}' to be invalid"
      end
    end

    it "rejects reserved subdomains" do
      registry = Sellia::Server::TunnelRegistry.new(
        Sellia::Server::Storage::Migrations.default_reserved_subdomains
      )
      %w[api www admin dashboard auth login].each do |subdomain|
        result = registry.validate_subdomain(subdomain)
        result.valid.should be_false, "Expected '#{subdomain}' to be reserved"
        result.error.not_nil!.should contain("reserved")
      end
    end

    it "rejects already taken subdomains" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456"
      )
      registry.register(tunnel)

      result = registry.validate_subdomain("myapp")
      result.valid.should be_false
      result.error.not_nil!.should contain("not available")
    end
  end

  describe "Tunnel struct" do
    it "stores auth when provided" do
      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456",
        auth: "user:pass"
      )

      tunnel.auth.should eq("user:pass")
    end

    it "has created_at timestamp" do
      before = Time.utc
      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456"
      )
      after = Time.utc

      tunnel.created_at.should be >= before
      tunnel.created_at.should be <= after
    end
  end
end
