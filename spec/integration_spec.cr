require "./spec_helper"
require "http/server"
require "http/client"

describe "Sellia Integration" do
  it "tunnels requests" do
    # 1. Start Dummy Target Server on port 3001 (avoiding 3000 in case it's used)
    target_port = 3001
    target_server = HTTP::Server.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello from Target! Path: #{context.request.path}"
    end
    address = target_server.bind_tcp("localhost", target_port)
    spawn { target_server.listen }

    # 2. Start Sellia Server on port 8081
    server_port = 8081
    sellia_server = Sellia::Server.new("localhost", server_port)
    spawn { sellia_server.start }

    # Give servers a moment to start
    sleep 0.1.seconds

    # 3. Start Sellia Client
    # Connects to localhost:8081, forwards to localhost:3001, subdomain 'test'
    sellia_client = Sellia::Client.new("localhost", server_port, target_port, "test")
    spawn { sellia_client.start }

    # Give client a moment to connect
    sleep 0.1.seconds

    # 4. Make request to Sellia Server
    # We want to hit test.localhost:8081
    # We can use HTTP::Client with a custom Host header

    headers = HTTP::Headers{"Host" => "test.localhost:#{server_port}"}
    client = HTTP::Client.new("localhost", server_port)
    response = client.get("/some/path", headers: headers)

    response.status_code.should eq(200)
    response.body.should eq("Hello from Target! Path: /some/path")

    client.close
    target_server.close
    # We can't easily close Sellia Server/Client cleanly without exposing methods, but for a spec it's fine
  end
end
