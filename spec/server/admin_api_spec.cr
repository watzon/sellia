require "../spec_helper"
require "http/server"
require "http/client"
require "json"
require "../../src/server/storage/storage"
require "../../src/server/admin_api"
require "../../src/server/auth_provider"
require "../../src/server/tunnel_registry"

module AdminAPIContext
  @@test_server : HTTP::Server?
  @@test_port : Int32?
  @@test_master_key : String = ""
  @@test_tunnel_registry : Sellia::Server::TunnelRegistry?

  def self.server=(value)
    @@test_server = value
  end

  def self.server
    @@test_server
  end

  def self.port=(value)
    @@test_port = value
  end

  def self.port
    @@test_port
  end

  def self.master_key=(value)
    @@test_master_key = value
  end

  def self.master_key
    @@test_master_key
  end

  def self.tunnel_registry=(value)
    @@test_tunnel_registry = value
  end

  def self.tunnel_registry
    @@test_tunnel_registry
  end

  def self.base_url
    "http://127.0.0.1:#{@@test_port}"
  end

  def self.host_with_port
    "127.0.0.1:#{@@test_port}"
  end

  def self.make_authenticated_request(method : String, path : String, body : String? = nil)
    HTTP::Client.new("127.0.0.1", @@test_port.not_nil!) do |client|
      client.before_request do |request|
        request.headers["Authorization"] = "Bearer #{@@test_master_key}"
        request.headers["X-API-Key"] = @@test_master_key
        if body
          request.headers["Content-Type"] = "application/json"
        end
      end

      case method
      when "GET"
        client.get(path)
      when "POST"
        client.post(path, body: body || "")
      when "DELETE"
        client.delete(path)
      else
        raise "Unknown method: #{method}"
      end
    end
  end

  def self.make_api_key_request(method : String, path : String, body : String? = nil)
    HTTP::Client.new("127.0.0.1", @@test_port.not_nil!) do |client|
      client.before_request do |request|
        request.headers["X-API-Key"] = @@test_master_key
        if body
          request.headers["Content-Type"] = "application/json"
        end
      end

      case method
      when "GET"
        client.get(path)
      when "POST"
        client.post(path, body: body || "")
      when "DELETE"
        client.delete(path)
      else
        raise "Unknown method: #{method}"
      end
    end
  end

  def self.make_request(method : String, path : String, headers : HTTP::Headers? = nil, body : String? = nil)
    HTTP::Client.new("127.0.0.1", @@test_port.not_nil!) do |client|
      case method
      when "GET"
        client.get(path, headers: headers)
      when "POST"
        client.post(path, headers: headers, body: body || "")
      when "DELETE"
        client.delete(path, headers: headers)
      else
        raise "Unknown method: #{method}"
      end
    end
  end
end

describe Sellia::Server::AdminAPI do
  describe "HTTP endpoints" do
    before_each do
      # Create a master API key for testing
      AdminAPIContext.master_key = Random::Secure.hex(32)
      Sellia::Server::Storage::Repositories::ApiKeys.create(AdminAPIContext.master_key, name: "Test Master", is_master: true)

      # Create auth provider
      auth_provider = Sellia::Server::AuthProvider.new(
        require_auth: true,
        master_key: nil,
        use_database: true
      )

      tunnel_registry = Sellia::Server::TunnelRegistry.new(
        Sellia::Server::Storage::Repositories::ReservedSubdomains.to_set
      )
      AdminAPIContext.tunnel_registry = tunnel_registry

      # Create admin API
      admin_api = Sellia::Server::AdminAPI.new(auth_provider, tunnel_registry)

      # Find an available port
      AdminAPIContext.port = Random::Secure.rand(4000..5000)

      # Start test server
      test_server = HTTP::Server.new do |context|
        if context.request.path.starts_with?("/api/admin/")
          admin_api.handle(context)
        else
          context.response.status = HTTP::Status::NOT_FOUND
        end
      end

      spawn do
        test_server.bind_tcp("127.0.0.1", AdminAPIContext.port.not_nil!)
        test_server.listen
      end

      AdminAPIContext.server = test_server

      # Give server time to start
      ::sleep 0.1.seconds
    end

    after_each do
      AdminAPIContext.server.try(&.close)
    end

    describe "GET /api/admin/reserved" do
      it "requires authentication" do
        response = AdminAPIContext.make_request("GET", "/api/admin/reserved")
        response.status_code.should eq 401
      end

      it "lists all reserved subdomains" do
        response = AdminAPIContext.make_authenticated_request("GET", "/api/admin/reserved")
        response.status_code.should eq 200

        data = JSON.parse(response.body)
        data.as_a.size.should be > 40
      end

      it "accepts authentication via X-API-Key only" do
        response = AdminAPIContext.make_api_key_request("GET", "/api/admin/reserved")
        response.status_code.should eq 200
      end
    end

    describe "POST /api/admin/reserved" do
      it "requires authentication" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = {subdomain: "test"}.to_json
        response = AdminAPIContext.make_request("POST", "/api/admin/reserved", headers: headers, body: body)
        response.status_code.should eq 401
      end

      it "adds a reserved subdomain" do
        body = {subdomain: "myreserved", reason: "Test reservation"}.to_json
        response = AdminAPIContext.make_authenticated_request("POST", "/api/admin/reserved", body)

        response.status_code.should eq 201

        data = JSON.parse(response.body)
        data["subdomain"].as_s.should eq "myreserved"
        data["reason"].as_s.should eq "Test reservation"
      end

      it "validates subdomain format" do
        body = {subdomain: "ab"}.to_json # Too short
        response = AdminAPIContext.make_authenticated_request("POST", "/api/admin/reserved", body)

        response.status_code.should eq 400
      end

      it "rejects duplicate subdomains" do
        body = {subdomain: "duplicate"}.to_json
        AdminAPIContext.make_authenticated_request("POST", "/api/admin/reserved", body)

        # Try to add again
        response = AdminAPIContext.make_authenticated_request("POST", "/api/admin/reserved", body)
        response.status_code.should eq 409
      end

      it "refreshes the registry after adding a reserved subdomain" do
        registry = AdminAPIContext.tunnel_registry.not_nil!

        registry.validate_subdomain("refreshtest").valid.should be_true

        body = {subdomain: "refreshtest", reason: "Test reservation"}.to_json
        response = AdminAPIContext.make_authenticated_request("POST", "/api/admin/reserved", body)
        response.status_code.should eq 201

        result = registry.validate_subdomain("refreshtest")
        result.valid.should be_false
        result.error.not_nil!.includes?("reserved").should be_true
      end
    end

    describe "DELETE /api/admin/reserved/:subdomain" do
      it "requires authentication" do
        response = AdminAPIContext.make_request("DELETE", "/api/admin/reserved/test")
        response.status_code.should eq 401
      end

      it "removes a custom reserved subdomain" do
        # Add a custom reserved subdomain first
        body = {subdomain: "todelete"}.to_json
        AdminAPIContext.make_authenticated_request("POST", "/api/admin/reserved", body)

        # Delete it
        response = AdminAPIContext.make_authenticated_request("DELETE", "/api/admin/reserved/todelete")
        response.status_code.should eq 200
      end

      it "does not allow removing default reserved subdomains" do
        response = AdminAPIContext.make_authenticated_request("DELETE", "/api/admin/reserved/api")
        response.status_code.should eq 403
      end

      it "refreshes the registry after removing a reserved subdomain" do
        registry = AdminAPIContext.tunnel_registry.not_nil!

        body = {subdomain: "refreshdelete"}.to_json
        AdminAPIContext.make_authenticated_request("POST", "/api/admin/reserved", body)
        registry.validate_subdomain("refreshdelete").valid.should be_false

        response = AdminAPIContext.make_authenticated_request("DELETE", "/api/admin/reserved/refreshdelete")
        response.status_code.should eq 200

        registry.validate_subdomain("refreshdelete").valid.should be_true
      end
    end

    describe "GET /api/admin/api-keys" do
      it "requires authentication" do
        response = AdminAPIContext.make_request("GET", "/api/admin/api-keys")
        response.status_code.should eq 401
      end

      it "lists all API keys" do
        response = AdminAPIContext.make_authenticated_request("GET", "/api/admin/api-keys")
        response.status_code.should eq 200

        data = JSON.parse(response.body)
        data.as_a.size.should be >= 1 # At least the master key we created
      end
    end

    describe "POST /api/admin/api-keys" do
      it "requires authentication" do
        headers = HTTP::Headers{"Content-Type" => "application/json"}
        body = ({} of String => JSON::Any).to_json
        response = AdminAPIContext.make_request("POST", "/api/admin/api-keys", headers: headers, body: body)
        response.status_code.should eq 401
      end

      it "creates a new API key" do
        body = {name: "New Key", is_master: false}.to_json
        response = AdminAPIContext.make_authenticated_request("POST", "/api/admin/api-keys", body)

        response.status_code.should eq 201

        data = JSON.parse(response.body)
        data["key"].as_s.should_not be_empty
        data["name"].as_s.should eq "New Key"
        data["is_master"].as_bool.should be_false
      end

      it "creates a master API key" do
        body = {name: "Admin Key", is_master: true}.to_json
        response = AdminAPIContext.make_authenticated_request("POST", "/api/admin/api-keys", body)

        response.status_code.should eq 201

        data = JSON.parse(response.body)
        data["is_master"].as_bool.should be_true
      end
    end

    describe "DELETE /api/admin/api-keys/:prefix" do
      it "requires authentication" do
        response = AdminAPIContext.make_request("DELETE", "/api/admin/api-keys/test")
        response.status_code.should eq 401
      end

      it "revokes an API key" do
        # Create a key first
        body = {name: "To Revoke", is_master: false}.to_json
        create_response = AdminAPIContext.make_authenticated_request("POST", "/api/admin/api-keys", body)
        key_prefix = JSON.parse(create_response.body)["key_prefix"].as_s

        # Revoke it
        response = AdminAPIContext.make_authenticated_request("DELETE", "/api/admin/api-keys/#{key_prefix}")
        response.status_code.should eq 200
      end
    end
  end

  describe "Admin auth without database or master key" do
    before_each do
      Sellia::Server::Storage::Database.close

      auth_provider = Sellia::Server::AuthProvider.new(
        require_auth: false,
        master_key: nil,
        use_database: false
      )

      admin_api = Sellia::Server::AdminAPI.new(auth_provider)

      AdminAPIContext.port = Random::Secure.rand(5001..6000)
      test_server = HTTP::Server.new do |context|
        if context.request.path.starts_with?("/api/admin/")
          admin_api.handle(context)
        else
          context.response.status = HTTP::Status::NOT_FOUND
        end
      end

      spawn do
        test_server.bind_tcp("127.0.0.1", AdminAPIContext.port.not_nil!)
        test_server.listen
      end

      AdminAPIContext.server = test_server
      ::sleep 0.1.seconds
    end

    after_each do
      AdminAPIContext.server.try(&.close)
      Sellia::Server::Storage::Database.open("/tmp/sellia_test_#{Process.pid}.db")
      Sellia::Server::Storage::Migrations.migrate
      Sellia::Server::Storage::Migrations.seed_default_reserved_subdomains
    end

    it "rejects requests without a master key or database" do
      headers = HTTP::Headers{"X-API-Key" => "anything"}
      response = AdminAPIContext.make_request("GET", "/api/admin/reserved", headers: headers)
      response.status_code.should eq 401
    end
  end
end
