require "../spec_helper"
require "http/server"
require "http/client"
require "../../src/server/server"
require "../../src/cli/tunnel_client"

# End-to-end integration tests for the Sellia tunnel system.
#
# These tests verify the complete tunnel flow:
# Browser/Client -> Tunnel Server -> Tunnel Client -> Local App -> Back
#
# Each test:
# 1. Starts a local HTTP server (simulates the user's app)
# 2. Starts the tunnel server
# 3. Connects a tunnel client
# 4. Makes requests through the tunnel
# 5. Verifies responses and cleans up

describe "End-to-end tunnel integration" do
  describe "Basic HTTP tunneling" do
    it "proxies a simple GET request through the tunnel" do
      local_port = 19899
      server_port = 19898
      tunnel_connected = Channel(String).new

      # Start a simple local HTTP server
      local_server = HTTP::Server.new do |ctx|
        ctx.response.content_type = "text/plain"
        ctx.response.print("Hello from local server!")
      end
      local_server.bind_tcp("127.0.0.1", local_port)

      spawn { local_server.listen }
      sleep 0.1.seconds

      # Start the tunnel server
      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      # Connect the tunnel client
      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port,
        subdomain: "test"
      )
      client.auto_reconnect = false

      client.on_connect { |url| tunnel_connected.send(url) }

      spawn { client.start }

      # Wait for tunnel to be ready
      select
      when url = tunnel_connected.receive
        url.should contain("test")
      when timeout(5.seconds)
        fail "Tunnel did not connect within timeout"
      end

      # Make a request through the tunnel
      http_client = HTTP::Client.new("127.0.0.1", server_port)
      http_client.before_request do |request|
        request.headers["Host"] = "test.127.0.0.1:#{server_port}"
      end

      response = http_client.get("/")

      response.status_code.should eq(200)
      response.body.should eq("Hello from local server!")

      # Cleanup
      client.stop
      local_server.close
      http_client.close
    end

    it "proxies POST requests with body" do
      local_port = 19997
      server_port = 19996
      received_body : String? = nil
      tunnel_connected = Channel(String).new

      # Local server that echoes the request body
      local_server = HTTP::Server.new do |ctx|
        if body = ctx.request.body
          received_body = body.gets_to_end
          ctx.response.content_type = "text/plain"
          ctx.response.print("Received: #{received_body}")
        else
          ctx.response.status_code = 400
          ctx.response.print("No body")
        end
      end
      local_server.bind_tcp("127.0.0.1", local_port)

      spawn { local_server.listen }
      sleep 0.1.seconds

      # Start tunnel server
      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      # Connect tunnel client
      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port,
        subdomain: "posttest"
      )
      client.auto_reconnect = false

      client.on_connect { |url| tunnel_connected.send(url) }

      spawn { client.start }

      # Wait for connection
      select
      when tunnel_connected.receive
        # Connected
      when timeout(5.seconds)
        fail "Tunnel did not connect within timeout"
      end

      # Make POST request through tunnel
      http_client = HTTP::Client.new("127.0.0.1", server_port)
      http_client.before_request do |request|
        request.headers["Host"] = "posttest.127.0.0.1:#{server_port}"
      end

      response = http_client.post("/submit", body: "test data payload")

      response.status_code.should eq(200)
      response.body.should eq("Received: test data payload")

      # Cleanup
      client.stop
      local_server.close
      http_client.close
    end

    it "handles multiple sequential requests" do
      local_port = 19995
      server_port = 19994
      request_count = 0
      tunnel_connected = Channel(String).new

      # Local server that counts requests
      local_server = HTTP::Server.new do |ctx|
        request_count += 1
        ctx.response.content_type = "text/plain"
        ctx.response.print("Request ##{request_count}")
      end
      local_server.bind_tcp("127.0.0.1", local_port)

      spawn { local_server.listen }
      sleep 0.1.seconds

      # Start tunnel server
      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      # Connect tunnel client
      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port,
        subdomain: "multi"
      )
      client.auto_reconnect = false

      client.on_connect { |url| tunnel_connected.send(url) }

      spawn { client.start }

      select
      when tunnel_connected.receive
        # Connected
      when timeout(5.seconds)
        fail "Tunnel did not connect within timeout"
      end

      # Make multiple requests
      http_client = HTTP::Client.new("127.0.0.1", server_port)
      http_client.before_request do |request|
        request.headers["Host"] = "multi.127.0.0.1:#{server_port}"
      end

      3.times do |i|
        response = http_client.get("/request/#{i}")
        response.status_code.should eq(200)
        response.body.should eq("Request ##{i + 1}")
      end

      request_count.should eq(3)

      # Cleanup
      client.stop
      local_server.close
      http_client.close
    end

    it "returns 404 for unknown subdomain" do
      server_port = 19993

      # Start tunnel server without any connected clients
      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      # Try to access a non-existent subdomain
      http_client = HTTP::Client.new("127.0.0.1", server_port)
      http_client.before_request do |request|
        request.headers["Host"] = "nonexistent.127.0.0.1:#{server_port}"
      end

      response = http_client.get("/")

      response.status_code.should eq(404)
      response.body.should contain("Tunnel not found")

      http_client.close
    end

    it "returns health check on root domain" do
      server_port = 19992

      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      http_client = HTTP::Client.new("127.0.0.1", server_port)

      response = http_client.get("/health")

      response.status_code.should eq(200)
      response.body.should contain("ok")
      response.body.should contain("tunnels")

      http_client.close
    end

    it "preserves response headers from local server" do
      local_port = 19991
      server_port = 19990
      tunnel_connected = Channel(String).new

      # Local server with custom headers
      local_server = HTTP::Server.new do |ctx|
        ctx.response.content_type = "application/json"
        ctx.response.headers["X-Custom-Header"] = "custom-value"
        ctx.response.headers["X-Another"] = "another-value"
        ctx.response.print(%({"status": "ok"}))
      end
      local_server.bind_tcp("127.0.0.1", local_port)

      spawn { local_server.listen }
      sleep 0.1.seconds

      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port,
        subdomain: "headers"
      )
      client.auto_reconnect = false

      client.on_connect { |url| tunnel_connected.send(url) }

      spawn { client.start }

      select
      when tunnel_connected.receive
        # Connected
      when timeout(5.seconds)
        fail "Tunnel did not connect within timeout"
      end

      http_client = HTTP::Client.new("127.0.0.1", server_port)
      http_client.before_request do |request|
        request.headers["Host"] = "headers.127.0.0.1:#{server_port}"
      end

      response = http_client.get("/api/data")

      response.status_code.should eq(200)
      response.headers["X-Custom-Header"]?.should eq("custom-value")
      response.headers["X-Another"]?.should eq("another-value")
      response.headers["Content-Type"]?.should eq("application/json")
      response.body.should eq(%({"status": "ok"}))

      client.stop
      local_server.close
      http_client.close
    end

    it "handles local server returning error status codes" do
      local_port = 19989
      server_port = 19988
      tunnel_connected = Channel(String).new

      # Local server that returns 500 error
      local_server = HTTP::Server.new do |ctx|
        ctx.response.status_code = 500
        ctx.response.content_type = "text/plain"
        ctx.response.print("Internal Server Error")
      end
      local_server.bind_tcp("127.0.0.1", local_port)

      spawn { local_server.listen }
      sleep 0.1.seconds

      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port,
        subdomain: "errors"
      )
      client.auto_reconnect = false

      client.on_connect { |url| tunnel_connected.send(url) }

      spawn { client.start }

      select
      when tunnel_connected.receive
        # Connected
      when timeout(5.seconds)
        fail "Tunnel did not connect within timeout"
      end

      http_client = HTTP::Client.new("127.0.0.1", server_port)
      http_client.before_request do |request|
        request.headers["Host"] = "errors.127.0.0.1:#{server_port}"
      end

      response = http_client.get("/trigger-error")

      response.status_code.should eq(500)
      response.body.should eq("Internal Server Error")

      client.stop
      local_server.close
      http_client.close
    end

    it "returns 502 when local server is unavailable" do
      server_port = 19987
      tunnel_connected = Channel(String).new

      # Start tunnel server
      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      # Connect client to a port where nothing is running
      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: 19000,  # No server running here
        subdomain: "nolocal"
      )
      client.auto_reconnect = false

      client.on_connect { |url| tunnel_connected.send(url) }

      spawn { client.start }

      select
      when tunnel_connected.receive
        # Connected
      when timeout(5.seconds)
        fail "Tunnel did not connect within timeout"
      end

      http_client = HTTP::Client.new("127.0.0.1", server_port)
      http_client.before_request do |request|
        request.headers["Host"] = "nolocal.127.0.0.1:#{server_port}"
      end

      response = http_client.get("/")

      response.status_code.should eq(502)
      response.body.should contain("unavailable")

      client.stop
      http_client.close
    end

    it "supports different HTTP methods" do
      local_port = 19986
      server_port = 19985
      tunnel_connected = Channel(String).new
      last_method : String? = nil

      # Local server that returns the HTTP method used
      local_server = HTTP::Server.new do |ctx|
        last_method = ctx.request.method
        ctx.response.content_type = "text/plain"
        ctx.response.print("Method: #{ctx.request.method}")
      end
      local_server.bind_tcp("127.0.0.1", local_port)

      spawn { local_server.listen }
      sleep 0.1.seconds

      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port,
        subdomain: "methods"
      )
      client.auto_reconnect = false

      client.on_connect { |url| tunnel_connected.send(url) }

      spawn { client.start }

      select
      when tunnel_connected.receive
        # Connected
      when timeout(5.seconds)
        fail "Tunnel did not connect within timeout"
      end

      http_client = HTTP::Client.new("127.0.0.1", server_port)
      http_client.before_request do |request|
        request.headers["Host"] = "methods.127.0.0.1:#{server_port}"
      end

      # Test GET
      response = http_client.get("/test")
      response.status_code.should eq(200)
      response.body.should eq("Method: GET")

      # Test POST
      response = http_client.post("/test", body: "data")
      response.status_code.should eq(200)
      response.body.should eq("Method: POST")

      # Test PUT
      response = http_client.put("/test", body: "data")
      response.status_code.should eq(200)
      response.body.should eq("Method: PUT")

      # Test DELETE
      response = http_client.delete("/test")
      response.status_code.should eq(200)
      response.body.should eq("Method: DELETE")

      client.stop
      local_server.close
      http_client.close
    end
  end

  describe "Authentication" do
    it "accepts valid API key when auth is required" do
      local_port = 19984
      server_port = 19983
      tunnel_connected = Channel(String).new

      local_server = HTTP::Server.new do |ctx|
        ctx.response.content_type = "text/plain"
        ctx.response.print("Authenticated!")
      end
      local_server.bind_tcp("127.0.0.1", local_port)

      spawn { local_server.listen }
      sleep 0.1.seconds

      # Tunnel server with auth required
      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: true,
        master_key: "secret-key-123"
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      # Client with correct API key
      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port,
        api_key: "secret-key-123",
        subdomain: "authed"
      )
      client.auto_reconnect = false

      client.on_connect { |url| tunnel_connected.send(url) }

      spawn { client.start }

      select
      when url = tunnel_connected.receive
        url.should contain("authed")
      when timeout(5.seconds)
        fail "Tunnel did not connect within timeout"
      end

      http_client = HTTP::Client.new("127.0.0.1", server_port)
      http_client.before_request do |request|
        request.headers["Host"] = "authed.127.0.0.1:#{server_port}"
      end

      response = http_client.get("/")

      response.status_code.should eq(200)
      response.body.should eq("Authenticated!")

      client.stop
      local_server.close
      http_client.close
    end

    it "rejects invalid API key" do
      server_port = 19982
      auth_error : String? = nil
      error_received = Channel(String).new

      # Tunnel server with auth required
      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: true,
        master_key: "correct-key"
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      # Client with wrong API key
      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: 9999,
        api_key: "wrong-key",
        subdomain: "badauth"
      )
      client.auto_reconnect = false

      client.on_error do |error|
        error_received.send(error)
      end

      spawn { client.start }

      select
      when error = error_received.receive
        error.should contain("Authentication failed")
      when timeout(5.seconds)
        fail "Should have received auth error"
      end

      client.stop
    end
  end

  describe "Subdomain management" do
    it "rejects duplicate subdomain requests" do
      local_port = 19981
      server_port = 19980
      first_connected = Channel(String).new
      second_error = Channel(String).new

      local_server = HTTP::Server.new do |ctx|
        ctx.response.print("Hello")
      end
      local_server.bind_tcp("127.0.0.1", local_port)

      spawn { local_server.listen }
      sleep 0.1.seconds

      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      # First client claims subdomain
      client1 = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port,
        subdomain: "unique"
      )
      client1.auto_reconnect = false

      client1.on_connect { |url| first_connected.send(url) }

      spawn { client1.start }

      select
      when first_connected.receive
        # First client connected
      when timeout(5.seconds)
        fail "First client did not connect"
      end

      # Second client tries same subdomain
      client2 = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port,
        subdomain: "unique"
      )
      client2.auto_reconnect = false

      client2.on_error { |error| second_error.send(error) }

      spawn { client2.start }

      select
      when error = second_error.receive
        error.should contain("not available")
      when timeout(5.seconds)
        fail "Should have received subdomain error"
      end

      client1.stop
      client2.stop
      local_server.close
    end

    it "generates random subdomain when not specified" do
      local_port = 19979
      server_port = 19978
      tunnel_connected = Channel(String).new

      local_server = HTTP::Server.new do |ctx|
        ctx.response.print("Random subdomain works!")
      end
      local_server.bind_tcp("127.0.0.1", local_port)

      spawn { local_server.listen }
      sleep 0.1.seconds

      tunnel_server = Sellia::Server::Server.new(
        host: "127.0.0.1",
        port: server_port,
        domain: "127.0.0.1:#{server_port}",
        require_auth: false
      )

      spawn { tunnel_server.start }
      sleep 0.2.seconds

      # Client without specified subdomain
      client = Sellia::CLI::TunnelClient.new(
        server_url: "http://127.0.0.1:#{server_port}",
        local_port: local_port
      )
      client.auto_reconnect = false

      client.on_connect { |url| tunnel_connected.send(url) }

      spawn { client.start }

      select
      when url = tunnel_connected.receive
        # URL should contain a generated subdomain (8 hex chars)
        url.should match(/http:\/\/[a-f0-9]{8}\.127\.0\.0\.1/)
      when timeout(5.seconds)
        fail "Tunnel did not connect within timeout"
      end

      client.stop
      local_server.close
    end
  end
end
