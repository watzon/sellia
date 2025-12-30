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

  it "responds to ping with pong through the tunnel" do
    local_port = 19973
    server_port = 19972
    tunnel_connected = Channel(String).new

    local_server = start_ws_local_server(local_port) do |socket|
      socket.on_ping { |message| socket.pong(message) }
    end

    client = start_tunnel_client(server_port, local_port, "wsping", tunnel_connected)

    socket, protocol, _headers = open_tunnel_ws(
      "wsping.127.0.0.1:#{server_port}",
      server_port,
      "/hmr",
      "vite-hmr"
    )

    protocol.ping("hi")

    info, payload = receive_frame_with_timeout(protocol, 5.seconds)
    info.opcode.should eq(HTTP::WebSocket::Protocol::Opcode::PONG)
    String.new(payload).should eq("hi")

    protocol.close
    socket.close
    client.stop
    local_server.close
  end

  it "propagates close frames through the tunnel" do
    local_port = 19971
    server_port = 19970
    tunnel_connected = Channel(String).new
    close_code = Channel(HTTP::WebSocket::CloseCode).new(1)

    local_server = start_ws_local_server(local_port) do |socket|
      socket.on_close { |code, _message| close_code.send(code) }
    end

    client = start_tunnel_client(server_port, local_port, "wsclose", tunnel_connected)

    socket, protocol, _headers = open_tunnel_ws(
      "wsclose.127.0.0.1:#{server_port}",
      server_port,
      "/hmr",
      "vite-hmr"
    )

    protocol.close(1000)

    select
    when code = close_code.receive
      ([HTTP::WebSocket::CloseCode::NormalClosure, HTTP::WebSocket::CloseCode::NoStatusReceived].includes?(code)).should eq(true)
    when timeout(5.seconds)
      fail "Close frame did not propagate to local server"
    end

    socket.close
    client.stop
    local_server.close
  end

  it "forwards binary frames through the tunnel" do
    local_port = 19969
    server_port = 19968
    tunnel_connected = Channel(String).new

    local_server = start_ws_local_server(local_port) do |socket|
      socket.on_binary { |bytes| socket.send(bytes) }
    end

    client = start_tunnel_client(server_port, local_port, "wsbin", tunnel_connected)

    socket, protocol, _headers = open_tunnel_ws(
      "wsbin.127.0.0.1:#{server_port}",
      server_port,
      "/hmr",
      "vite-hmr"
    )

    payload = Bytes.new(5) { |i| (i + 1).to_u8 }
    protocol.send(payload)

    info, received = receive_frame_with_timeout(protocol, 5.seconds)
    info.opcode.should eq(HTTP::WebSocket::Protocol::Opcode::BINARY)
    received.should eq(payload)

    protocol.close
    socket.close
    client.stop
    local_server.close
  end

  it "selects the first subprotocol when multiple are requested" do
    local_port = 19967
    server_port = 19966
    tunnel_connected = Channel(String).new

    local_server = start_ws_local_server(local_port) do |socket|
      socket.on_message { |msg| socket.send(msg) }
    end

    client = start_tunnel_client(server_port, local_port, "wsproto", tunnel_connected)

    socket, _protocol, headers = open_tunnel_ws(
      "wsproto.127.0.0.1:#{server_port}",
      server_port,
      "/hmr",
      "vite-hmr, other"
    )

    headers["sec-websocket-protocol"]?.should eq("vite-hmr")

    socket.close
    client.stop
    local_server.close
  end

  it "supports large text payloads through the tunnel" do
    local_port = 19965
    server_port = 19964
    tunnel_connected = Channel(String).new

    local_server = start_ws_local_server(local_port) do |socket|
      socket.on_message { |msg| socket.send(msg) }
    end

    client = start_tunnel_client(server_port, local_port, "wslarge", tunnel_connected)

    socket, protocol, _headers = open_tunnel_ws(
      "wslarge.127.0.0.1:#{server_port}",
      server_port,
      "/hmr",
      "vite-hmr"
    )

    message = "a" * 20000
    protocol.send(message)

    echoed = read_text_message_with_timeout(protocol, 5.seconds)
    echoed.should eq(message)

    protocol.close
    socket.close
    client.stop
    local_server.close
  end

  it "supports multiple simultaneous WebSocket connections" do
    local_port = 19963
    server_port = 19962
    tunnel_connected = Channel(String).new

    local_server = start_ws_local_server(local_port) do |socket|
      socket.on_message { |msg| socket.send("echo:#{msg}") }
    end

    client = start_tunnel_client(server_port, local_port, "wsmulti", tunnel_connected)

    socket_a, protocol_a, _headers_a = open_tunnel_ws(
      "wsmulti.127.0.0.1:#{server_port}",
      server_port,
      "/hmr",
      "vite-hmr"
    )
    socket_b, protocol_b, _headers_b = open_tunnel_ws(
      "wsmulti.127.0.0.1:#{server_port}",
      server_port,
      "/hmr",
      "vite-hmr"
    )

    protocol_a.send("one")
    protocol_b.send("two")

    echo_a = read_text_message_with_timeout(protocol_a, 5.seconds)
    echo_b = read_text_message_with_timeout(protocol_b, 5.seconds)

    echo_a.should eq("echo:one")
    echo_b.should eq("echo:two")

    protocol_a.close
    protocol_b.close
    socket_a.close
    socket_b.close
    client.stop
    local_server.close
  end
end

private def start_ws_local_server(port : Int32, &block : HTTP::WebSocket ->) : HTTP::Server
  ws_handler = HTTP::WebSocketHandler.new do |socket, _ctx|
    block.call(socket)
  end
  local_server = HTTP::Server.new([ws_handler])
  local_server.bind_tcp("127.0.0.1", port)
  spawn { local_server.listen }
  sleep 0.1.seconds
  local_server
end

private def start_tunnel_client(
  server_port : Int32,
  local_port : Int32,
  subdomain : String,
  tunnel_connected : Channel(String),
) : Sellia::CLI::TunnelClient
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
    subdomain: subdomain
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

  client
end

private def open_tunnel_ws(
  host : String,
  server_port : Int32,
  path : String,
  subprotocol : String? = nil,
) : {TCPSocket, HTTP::WebSocket::Protocol, Hash(String, String)}
  socket = TCPSocket.new("127.0.0.1", server_port)
  ws_key = Base64.strict_encode(Random::Secure.random_bytes(16))
  request = String.build do |io|
    io << "GET #{path} HTTP/1.1\r\n"
    io << "Host: #{host}\r\n"
    io << "Upgrade: websocket\r\n"
    io << "Connection: Upgrade\r\n"
    io << "Sec-WebSocket-Key: #{ws_key}\r\n"
    io << "Sec-WebSocket-Version: 13\r\n"
    if subprotocol
      io << "Sec-WebSocket-Protocol: #{subprotocol}\r\n"
    end
    io << "\r\n"
  end
  socket << request
  socket.flush

  response = read_http_response(socket)
  status_line, headers = parse_http_headers(response)
  status_line.should contain("101")

  if subprotocol
    expected_protocol = subprotocol.split(',').map(&.strip).reject(&.empty?).first?
    headers["sec-websocket-protocol"]?.should eq(expected_protocol)
  end

  protocol = HTTP::WebSocket::Protocol.new(socket, masked: true, sync_close: false)
  {socket, protocol, headers}
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

private def receive_frame_with_timeout(
  protocol : HTTP::WebSocket::Protocol,
  timeout_span : Time::Span,
) : {HTTP::WebSocket::Protocol::PacketInfo, Bytes}
  result = Channel({HTTP::WebSocket::Protocol::PacketInfo, Bytes}).new(1)
  spawn do
    buffer = Bytes.new(8192)
    loop do
      info = protocol.receive(buffer)
      payload = Bytes.new(info.size)
      payload.copy_from(buffer.to_unsafe, info.size)
      result.send({info, payload})
      break
    end
  end

  select
  when data = result.receive
    data
  when timeout(timeout_span)
    fail "Timed out waiting for WebSocket frame"
  end
end

private def read_text_message_with_timeout(
  protocol : HTTP::WebSocket::Protocol,
  timeout_span : Time::Span,
) : String
  result = Channel(String).new(1)
  spawn do
    buffer = Bytes.new(8192)
    message = IO::Memory.new
    loop do
      info = protocol.receive(buffer)
      case info.opcode
      when HTTP::WebSocket::Protocol::Opcode::TEXT, HTTP::WebSocket::Protocol::Opcode::CONTINUATION
        message.write(buffer[0, info.size])
        if info.final
          result.send(message.to_s)
          break
        end
      when HTTP::WebSocket::Protocol::Opcode::PING
        protocol.pong(String.new(buffer[0, info.size]))
      end
    end
  end

  select
  when msg = result.receive
    msg
  when timeout(timeout_span)
    fail "Timed out waiting for WebSocket text message"
  end
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
