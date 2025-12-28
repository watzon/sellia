require "../spec_helper"
require "../../src/cli/config"

describe Sellia::CLI::Config do
  describe ".from_yaml" do
    it "loads config from YAML string" do
      yaml = <<-YAML
      server: https://example.com
      api_key: sk_test_123
      inspector:
        port: 4040
      YAML

      config = Sellia::CLI::Config.from_yaml(yaml)
      config.server.should eq("https://example.com")
      config.api_key.should eq("sk_test_123")
      config.inspector.port.should eq(4040)
    end

    it "uses defaults for missing values" do
      config = Sellia::CLI::Config.new
      config.server.should eq("https://to.sellia.me")
      config.inspector.port.should eq(4040)
    end

    it "parses inspector open setting" do
      yaml = <<-YAML
      inspector:
        port: 5050
        open: true
      YAML

      config = Sellia::CLI::Config.from_yaml(yaml)
      config.inspector.port.should eq(5050)
      config.inspector.open.should be_true
    end

    it "parses tunnel configurations" do
      yaml = <<-YAML
      tunnels:
        web:
          type: http
          port: 3000
          subdomain: myapp
        api:
          type: http
          port: 4000
          auth: "user:pass"
          local_host: 127.0.0.1
      YAML

      config = Sellia::CLI::Config.from_yaml(yaml)
      config.tunnels.size.should eq(2)

      web = config.tunnels["web"]
      web.type.should eq("http")
      web.port.should eq(3000)
      web.subdomain.should eq("myapp")

      api = config.tunnels["api"]
      api.port.should eq(4000)
      api.auth.should eq("user:pass")
      api.local_host.should eq("127.0.0.1")
    end
  end

  describe "#merge" do
    it "merges two configs with later taking precedence" do
      base = Sellia::CLI::Config.from_yaml(<<-YAML)
      server: https://base.com
      api_key: base_key
      YAML

      overlay = Sellia::CLI::Config.from_yaml(<<-YAML)
      api_key: overlay_key
      YAML

      merged = base.merge(overlay)
      merged.server.should eq("https://base.com")
      merged.api_key.should eq("overlay_key")
    end

    it "merges inspector settings" do
      base = Sellia::CLI::Config.from_yaml(<<-YAML)
      inspector:
        port: 5000
        open: false
      YAML

      overlay = Sellia::CLI::Config.from_yaml(<<-YAML)
      inspector:
        open: true
      YAML

      merged = base.merge(overlay)
      merged.inspector.port.should eq(5000)
      merged.inspector.open.should be_true
    end

    it "merges tunnel configurations" do
      base = Sellia::CLI::Config.from_yaml(<<-YAML)
      tunnels:
        web:
          port: 3000
      YAML

      overlay = Sellia::CLI::Config.from_yaml(<<-YAML)
      tunnels:
        api:
          port: 4000
      YAML

      merged = base.merge(overlay)
      merged.tunnels.size.should eq(2)
      merged.tunnels.has_key?("web").should be_true
      merged.tunnels.has_key?("api").should be_true
    end
  end

  describe Sellia::CLI::Config::Inspector do
    it "has default values" do
      inspector = Sellia::CLI::Config::Inspector.new
      inspector.port.should eq(4040)
      inspector.open.should be_false
    end
  end

  describe Sellia::CLI::Config::TunnelConfig do
    it "has sensible defaults" do
      tunnel = Sellia::CLI::Config::TunnelConfig.new(port: 8080)
      tunnel.type.should eq("http")
      tunnel.port.should eq(8080)
      tunnel.local_host.should eq("localhost")
      tunnel.subdomain.should be_nil
      tunnel.auth.should be_nil
    end
  end
end
