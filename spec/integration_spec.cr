require "./spec_helper"
require "http/server"
require "http/client"

describe "Sellia Integration" do
  it "tunnels requests and rewrites Host header" do
    # 1. Start Dummy Target Server on port 3001
    target_port = 3001
    target_server = HTTP::Server.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Host: #{context.request.headers["Host"]?}"
    end
    target_server.bind_tcp("localhost", target_port)
    spawn { target_server.listen }

    # 2. Start Sellia Server on port 8081
    server_port = 8081
    domain = "localhost"
    sellia_server = Sellia::Server.new("localhost", server_port, domain)
    spawn { sellia_server.start }

    # Give servers a moment to start
    sleep 0.5.seconds

    # 3. Start Sellia Client
    # Connects to localhost:8081, forwards to localhost:3001, subdomain 'test'
    # Explicitly set local_host to "custom.local" to verify rewriting
    sellia_client = Sellia::Client.new("localhost", server_port, target_port, "test", "custom.local")
    spawn { sellia_client.start }

    # Give client a moment to connect and establish tunnel
    sleep 1.seconds

    # 4. Make request to Sellia Server
    # We want to hit test.localhost:8081
    # Note: In the new architecture, the client requests a tunnel, gets a port, connects to it.
    # The public URL is http://test.localhost:8081 (handled by Server proxy)

    headers = HTTP::Headers{"Host" => "test.localhost:#{server_port}"}
    client = HTTP::Client.new("localhost", server_port)
    response = client.get("/some/path", headers: headers)

    response.status_code.should eq(200)
    # Verify Host header was rewritten to "custom.local"
    response.body.should eq("Host: custom.local")

    client.close
    target_server.close
  end
end
