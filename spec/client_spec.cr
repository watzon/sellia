require "./spec_helper"
require "http/server"
require "http/client"

describe Sellia::Client do
  # 1. Start Dummy Target Server
  # It echoes the Host header in the body
  target_port = 3002
  target_server = HTTP::Server.new do |context|
    context.response.content_type = "text/plain"
    # Echo the Host header
    context.response.print context.request.headers["Host"]? || "No Host"
  end
  target_server.bind_tcp("localhost", target_port)
  spawn { target_server.listen }

  # 2. Start Sellia Server (The Tunnel Server)
  server_port = 8086
  domain = "localhost"
  sellia_server = Sellia::Server.new("localhost", server_port, domain)
  spawn { sellia_server.start }

  # Give servers a moment
  sleep 0.5.seconds

  it "query localtunnel server w/ ident" do
    # No subdomain specified, should get random
    # We need to capture the assigned URL.
    # Sellia::Client prints it to stdout, but doesn't expose it easily if we just spawn it.
    # We might need to modify Sellia::Client to expose the assigned URL or return it from start (if blocking) or have a getter.
    # Sellia::Client#start blocks?
    # Let's check client.cr.
    # It blocks on `cluster.start` which sleeps.

    # We'll run Client in a fiber.
    # But we need to know the URL it got.
    # We can modify Client to expose `public_url`.

    client = Sellia::Client.new("localhost", server_port, target_port, nil)
    spawn { client.start }
    sleep 1.seconds

    # We don't know the random ID easily without modifying Client to expose it.
    # Localtunnel's test uses the library function which returns a tunnel instance with .url.
    # Our Client is a class that runs the whole show.
    # I should modify Sellia::Client to expose `public_url` and maybe `tunnel_cluster`.

    # For now, I'll assume I can access it if I add a getter.
    # I will add a getter for `public_url` to Sellia::Client.

    client.public_url.should match(/^http:\/\/.*\.localhost$/)

    # Make request to the tunnel
    # We need to parse the URL to get the host/port for HTTP::Client
    # URL: http://<id>.localhost
    # We are testing against localhost:8086
    # So we request http://localhost:8086 with Host: <id>.localhost

    uri = URI.parse(client.public_url.not_nil!)
    tunnel_host = uri.host.not_nil!

    # The server is listening on server_port (8086)
    # We send request to localhost:8086 with Host: tunnel_host

    http_client = HTTP::Client.new("localhost", server_port)
    response = http_client.get("/", headers: HTTP::Headers{"Host" => tunnel_host})

    response.status_code.should eq(200)
    # The target server echoes the Host header.
    # By default, Sellia Client rewrites Host to "localhost" (default local_host).
    response.body.should eq("localhost")

    http_client.close
    client.stop # Need to implement stop
  end

  it "request specific domain" do
    subdomain = "specific-test-#{Random.rand(1000)}"
    client = Sellia::Client.new("localhost", server_port, target_port, subdomain)
    spawn { client.start }
    sleep 1.seconds

    expected_url = "http://#{subdomain}.localhost"
    client.public_url.should eq(expected_url)

    client.stop
  end

  it "override Host header with local-host (localhost)" do
    client = Sellia::Client.new("localhost", server_port, target_port, nil, "localhost")
    spawn { client.start }
    sleep 1.seconds

    uri = URI.parse(client.public_url.not_nil!)
    tunnel_host = uri.host.not_nil!

    http_client = HTTP::Client.new("localhost", server_port)
    response = http_client.get("/", headers: HTTP::Headers{"Host" => tunnel_host})

    response.body.should eq("localhost")

    http_client.close
    client.stop
  end

  it "override Host header with local-host (127.0.0.1)" do
    client = Sellia::Client.new("localhost", server_port, target_port, nil, "127.0.0.1")
    spawn { client.start }
    sleep 1.seconds

    uri = URI.parse(client.public_url.not_nil!)
    tunnel_host = uri.host.not_nil!

    http_client = HTTP::Client.new("localhost", server_port)
    response = http_client.get("/", headers: HTTP::Headers{"Host" => tunnel_host})

    response.body.should eq("127.0.0.1")

    http_client.close
    client.stop
  end
end
