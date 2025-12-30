require "../spec_helper"
require "../../src/server/ws_gateway"
require "../../src/server/connection_manager"
require "../../src/server/tunnel_registry"
require "../../src/server/auth_provider"
require "../../src/server/pending_request"
require "../../src/server/pending_websocket"
require "../../src/server/rate_limiter"

class Sellia::Server::WSGateway
  def run_heartbeat_check_for_test
    check_connections
  end
end

describe Sellia::Server::WSGateway do
  it "closes stale connections" do
    io = IO::Memory.new
    socket = HTTP::WebSocket.new(io)
    client = Sellia::Server::ClientConnection.new(socket)
    client.last_activity = Time.utc - 61.seconds

    connection_manager = Sellia::Server::ConnectionManager.new
    connection_manager.add_connection(client)

    gateway = Sellia::Server::WSGateway.new(
      connection_manager: connection_manager,
      tunnel_registry: Sellia::Server::TunnelRegistry.new,
      auth_provider: Sellia::Server::AuthProvider.new(false),
      pending_requests: Sellia::Server::PendingRequestStore.new,
      pending_websockets: Sellia::Server::PendingWebSocketStore.new,
      rate_limiter: Sellia::Server::CompositeRateLimiter.new(enabled: false),
      domain: "localhost",
      port: 3000,
      use_https: false
    )

    gateway.run_heartbeat_check_for_test

    client.closed?.should eq(true)
  end

  it "pings active connections" do
    io = IO::Memory.new
    socket = HTTP::WebSocket.new(io)
    client = Sellia::Server::ClientConnection.new(socket)
    client.last_activity = Time.utc

    connection_manager = Sellia::Server::ConnectionManager.new
    connection_manager.add_connection(client)

    gateway = Sellia::Server::WSGateway.new(
      connection_manager: connection_manager,
      tunnel_registry: Sellia::Server::TunnelRegistry.new,
      auth_provider: Sellia::Server::AuthProvider.new(false),
      pending_requests: Sellia::Server::PendingRequestStore.new,
      pending_websockets: Sellia::Server::PendingWebSocketStore.new,
      rate_limiter: Sellia::Server::CompositeRateLimiter.new(enabled: false),
      domain: "localhost",
      port: 3000,
      use_https: false
    )

    size_before = io.size
    gateway.run_heartbeat_check_for_test

    io.size.should be > size_before
    client.closed?.should eq(false)
  end
end
