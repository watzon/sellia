require "./spec_helper"

describe Sellia::TunnelManager do
  it "should construct with no tunnels" do
    manager = Sellia::TunnelManager.new
    manager.open_tunnels_count.should eq(0)
  end

  it "should create a new client with random id" do
    manager = Sellia::TunnelManager.new
    client = manager.new_client
    manager.has_client?(client.client_id).should be_true
    manager.remove_client(client.client_id)
    manager.has_client?(client.client_id).should be_false
  end

  it "should create a new client with id" do
    manager = Sellia::TunnelManager.new
    client = manager.new_client("foobar")
    client.client_id.should eq("foobar")
    manager.has_client?("foobar").should be_true
    manager.remove_client("foobar")
    manager.has_client?("foobar").should be_false
  end

  it "should create a new client with random id if previous exists" do
    manager = Sellia::TunnelManager.new
    client_a = manager.new_client("foobar")
    client_b = manager.new_client("foobar")

    client_a.client_id.should eq("foobar")
    manager.has_client?(client_b.client_id).should be_true
    client_b.client_id.should_not eq(client_a.client_id)

    manager.remove_client(client_b.client_id)
    manager.remove_client("foobar")
  end

  # Note: The "remove client once it goes offline" test requires mocking the TunnelAgent's socket/connection behavior
  # which is complex to port 1:1 without a full mock object framework or refactoring TunnelAgent.
  # For now, we test the explicit removal.
end
