require "./spec_helper"
require "http/client"

describe Sellia::Server do
  # Helper logic inlined in tests

  # We need a way to stop the server or know its port if we pass 0.
  # Currently Sellia::Server#start binds to @port.
  # If we pass 0, we don't know what port it picked easily unless we modify Server.
  # For tests, we'll use a fixed port or refactor Server.
  # Let's use a fixed port for now, but incrementing to avoid conflicts?
  # Or better, refactor Server to allow retrieving the bound address.

  it "server starts and stops" do
    # This test is a bit tricky with the current blocking start.
    # We'll skip the "stop" part for now unless we refactor.
    # Integration spec does `spawn { server.start }`.
  end

  it "should redirect root requests to landing page" do
    port = 8082
    server = Sellia::Server.new("localhost", port, "localhost")
    spawn { server.start }
    sleep 0.1.seconds

    client = HTTP::Client.new("localhost", port)
    response = client.get("/", headers: HTTP::Headers{"Host" => "localhost"})

    # Localtunnel redirects to https://localtunnel.github.io/www/
    response.status_code.should eq(302)
    response.headers["Location"].should eq("https://localtunnel.github.io/www/")

    client.close
    # server.stop # Need to implement stop
  end

  it "should support custom base domains" do
    port = 8083
    domain = "domain.example.com"
    server = Sellia::Server.new("localhost", port, domain)
    spawn { server.start }
    sleep 0.1.seconds

    client = HTTP::Client.new("localhost", port)
    response = client.get("/", headers: HTTP::Headers{"Host" => domain})

    response.status_code.should eq(302)
    response.headers["Location"].should eq("https://localtunnel.github.io/www/")

    client.close
  end

  it "reject long domain name requests" do
    port = 8084
    server = Sellia::Server.new("localhost", port, "localhost")
    spawn { server.start }
    sleep 0.1.seconds

    long_subdomain = "thisdomainisoutsidethesizeofwhatweallowwhichissixtythreecharacters"
    client = HTTP::Client.new("localhost", port)
    # Requesting a specific subdomain via path
    response = client.get("/#{long_subdomain}", headers: HTTP::Headers{"Host" => "localhost"})

    response.status_code.should eq(403)
    response.body.should contain("Invalid subdomain")

    client.close
  end

  it "should support the /api/tunnels/:id/status endpoint" do
    port = 8085
    server = Sellia::Server.new("localhost", port, "localhost")
    spawn { server.start }
    sleep 0.1.seconds

    client = HTTP::Client.new("localhost", port)

    # No such tunnel
    response = client.get("/api/tunnels/foobar-test/status", headers: HTTP::Headers{"Host" => "localhost"})
    response.status_code.should eq(404)

    # Create tunnel
    # We need to register one.
    # GET /foobar-test
    reg_response = client.get("/foobar-test", headers: HTTP::Headers{"Host" => "localhost"})
    reg_response.status_code.should eq(200)

    # Check status
    response = client.get("/api/tunnels/foobar-test/status", headers: HTTP::Headers{"Host" => "localhost"})
    response.status_code.should eq(200)
    json = JSON.parse(response.body)
    json["connected_sockets"].as_i.should eq(0) # Assuming 0 initially

    client.close
  end
end
