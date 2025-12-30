require "../spec_helper"
require "base64"
require "socket"
require "http/server"
require "http/web_socket"
require "../../src/server/server"
require "../../src/cli/tunnel_client"

describe "WebSocket tunnel integration" do
  it "echoes the requested subprotocol during the handshake" do
    local_port = 19977
    server_port = 19976
    tunnel_connected = Channel(String).new

    ws_handler = HTTP::WebSocketHandler.new do |socket, _ctx|
      socket.on_message { |msg| socket.send(msg) }
    end
    local_server = HTTP::Server.new([ws_handler]) do |ctx|
      ctx.response.status_code = 404
      ctx.response.print("Not Found")
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
      subdomain: "wsapp"
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

    socket = TCPSocket.new("127.0.0.1", server_port)
    ws_key = Base64.strict_encode(Random::Secure.random_bytes(16))
    request = String.build do |io|
      io << "GET /hmr HTTP/1.1\r\n"
      io << "Host: wsapp.127.0.0.1:#{server_port}\r\n"
      io << "Upgrade: websocket\r\n"
      io << "Connection: Upgrade\r\n"
      io << "Sec-WebSocket-Key: #{ws_key}\r\n"
      io << "Sec-WebSocket-Version: 13\r\n"
      io << "Sec-WebSocket-Protocol: vite-hmr\r\n"
      io << "\r\n"
    end
    socket << request
    socket.flush

    response = read_http_response(socket)
    status_line, headers = parse_http_headers(response)

    status_line.should contain("101")
    headers["upgrade"]?.try(&.downcase).should eq("websocket")
    headers["connection"]?.try(&.downcase).should eq("upgrade")
    headers["sec-websocket-accept"]?.should_not be_nil
    headers["sec-websocket-protocol"]?.should eq("vite-hmr")

    socket.close
    client.stop
    local_server.close
  end

  it "forwards WebSocket frames through the tunnel" do
    local_port = 19975
    server_port = 19974
    tunnel_connected = Channel(String).new

    ws_handler = HTTP::WebSocketHandler.new do |socket, _ctx|
      socket.on_message { |msg| socket.send("echo:#{msg}") }
    end
    local_server = HTTP::Server.new([ws_handler])
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
      subdomain: "wsframe"
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

    socket = TCPSocket.new("127.0.0.1", server_port)
    ws_key = Base64.strict_encode(Random::Secure.random_bytes(16))
    request = String.build do |io|
      io << "GET /hmr HTTP/1.1\r\n"
      io << "Host: wsframe.127.0.0.1:#{server_port}\r\n"
      io << "Upgrade: websocket\r\n"
      io << "Connection: Upgrade\r\n"
      io << "Sec-WebSocket-Key: #{ws_key}\r\n"
      io << "Sec-WebSocket-Version: 13\r\n"
      io << "Sec-WebSocket-Protocol: vite-hmr\r\n"
      io << "\r\n"
    end
    socket << request
    socket.flush

    response = read_http_response(socket)
    status_line, _headers = parse_http_headers(response)
    status_line.should contain("101")

    protocol = HTTP::WebSocket::Protocol.new(socket, masked: true, sync_close: false)
    protocol.send("ping")

    buffer = Bytes.new(1024)
    info = protocol.receive(buffer)
    info.opcode.should eq(HTTP::WebSocket::Protocol::Opcode::TEXT)
    String.new(buffer[0, info.size]).should eq("echo:ping")

    protocol.close
    client.stop
    local_server.close
  end
end

private def read_http_response(socket : TCPSocket) : String
  response = ""
  buffer = Bytes.new(1024)
  loop do
    read = socket.read(buffer)
    break if read == 0
    response += String.new(buffer[0, read])
    break if response.includes?("\r\n\r\n")
  end
  response
end

private def parse_http_headers(response : String) : {String, Hash(String, String)}
  header_block = response.split("\r\n\r\n", 2).first? || ""
  lines = header_block.split("\r\n")
  status_line = lines.shift? || ""
  headers = {} of String => String
  lines.each do |line|
    name, value = line.split(":", 2)
    next unless value
    headers[name.downcase] = value.strip
  end
  {status_line, headers}
end
