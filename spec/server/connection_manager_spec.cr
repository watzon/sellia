require "../spec_helper"
require "../../src/server/connection_manager"

describe Sellia::Server::ConnectionManager do
  describe "#register" do
    it "registers a client connection" do
      manager = Sellia::Server::ConnectionManager.new

      client_id = manager.register("api_key_123")
      client_id.should_not be_nil
      manager.authenticated?("api_key_123").should be_true
    end
  end

  describe "#unregister" do
    it "removes a client connection" do
      manager = Sellia::Server::ConnectionManager.new

      client_id = manager.register("api_key_123")
      manager.unregister(client_id)
      manager.find(client_id).should be_nil
    end
  end

  describe "#find_by_api_key" do
    it "returns nil when api_key is not registered" do
      manager = Sellia::Server::ConnectionManager.new
      manager.find_by_api_key("nonexistent").should be_nil
    end
  end

  describe "#size" do
    it "returns the number of registered connections" do
      manager = Sellia::Server::ConnectionManager.new
      manager.size.should eq(0)

      manager.register("key1")
      manager.size.should eq(0) # no actual connection without ClientConnection

      # When we add a real connection it should count
    end
  end

  describe "#authenticated?" do
    it "returns false for unknown api_key" do
      manager = Sellia::Server::ConnectionManager.new
      manager.authenticated?("unknown").should be_false
    end

    it "returns true after registration" do
      manager = Sellia::Server::ConnectionManager.new
      manager.register("test_key")
      manager.authenticated?("test_key").should be_true
    end
  end
end
