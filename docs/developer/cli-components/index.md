# CLI Components

Client-side implementation details for the Sellia CLI.

## Overview

The Sellia CLI (`sellia`) is responsible for creating tunnels to the local server, managing connections, and providing the request inspector. This section covers the client architecture and key components.

## Architecture

```
User Command
     ↓
   OptionParser
     ↓
 Tunnel Client
     ↓
WebSocket to Server ←→ Local Service
     ↓
 Inspector Server
     ↓
  Web UI
```

## Key Components

### Tunnel Client

**Location:** `src/cli/tunnel_client.cr`

Core client that connects to the Sellia server.

```crystal
class Sellia::CLI::TunnelClient
  def initialize(
    @server_url : String,
    @local_port : Int32,
    @api_key : String? = nil,
    @local_host : String = "localhost",
    @subdomain : String? = nil,
    @auth : String? = nil,
    @request_store : RequestStore? = nil,
    routes : Array(RouteConfig) = [] of RouteConfig,
  )
    @proxy = LocalProxy.new(@local_host, @local_port)
    @router = Router.new(routes, @local_host, @local_port > 0 ? @local_port : nil)
  end

  def start
    @running = true
    @reconnect_attempts = 0
    connect
  end

  def stop
    @running = false
    @connected = false
    @authenticated = false
    @socket.try(&.close)
    # ... cleanup
  end

  # Callbacks
  def on_connect(&block : String ->)
    @on_connect = block
  end

  def on_request(&block : Protocol::Messages::RequestStart ->)
    @on_request = block
  end
end
```

**Responsibilities:**
- Connect to server via WebSocket
- Authenticate with API key if provided
- Open tunnel and handle incoming requests
- Route requests to local services
- Forward responses back to server
- Handle WebSocket upgrade requests
- Auto-reconnect on disconnect

### Local Proxy

**Location:** `src/cli/local_proxy.cr`

HTTP proxy that forwards requests to local service.

```crystal
class Sellia::CLI::LocalProxy
  def initialize(@host : String, @port : Int32)
  end

  def forward(request : TunnelRequest) : TunnelResponse
    # Build HTTP request
    uri = URI.parse("http://#{@host}:#{@port}#{request.url}")

    client = HTTP::Client.new(uri)
    client.before_request do |req|
      req.method = request.method
      request.headers.each do |key, value|
        req.headers[key] = value
      end
      req.body = request.body if request.body
    end

    # Execute request
    response = client.exec(request.method, request.url)

    # Build tunnel response
    TunnelResponse.new(
      request_id: request.request_id,
      status_code: response.status_code,
      headers: response.headers.to_h,
      body: response.body?
    )
  end
end
```

**Responsibilities:**
- Receive requests from tunnel client
- Forward to local service
- Return responses to tunnel client
- Handle connection errors

### Inspector Server

**Location:** `src/cli/inspector.cr`

Local HTTP server for the inspector UI.

```crystal
class Sellia::CLI::Inspector
  property port : Int32
  property store : RequestStore

  def initialize(@port : Int32, @store : RequestStore)
  end

  def start
    @running = true
    server = HTTP::Server.new do |context|
      handle_request(context)
    end

    @server = server
    address = server.bind_tcp("127.0.0.1", @port)
    Log.info { "Inspector running at http://#{address}" }
    server.listen
  end

  def stop
    @running = false
    @server.try(&.close)
  end

  def running? : Bool
    @running
  end
end
```

**Responsibilities:**
- Serve inspector UI (React SPA)
- WebSocket endpoint for real-time updates
- REST API for request history
- Broadcast requests to connected clients
- Support development mode (Vite proxy) and production mode (baked assets)

### Configuration

**Location:** `src/cli/config.cr`

Loads and manages configuration.

```crystal
class Sellia::CLI::Config
  include YAML::Serializable

  property server : String = "https://sellia.me"
  property api_key : String?
  property inspector : Inspector = Inspector.new
  property database : DatabaseConfig = DatabaseConfig.new
  property tunnels : Hash(String, TunnelConfig) = {} of String => TunnelConfig

  def self.load : Config
    config = Config.new

    # Load in order of increasing priority
    paths = [
      Path.home / ".config" / "sellia" / "sellia.yml",
      Path.home / ".sellia.yml",
      Path.new("sellia.yml"),
    ]

    paths.each do |path|
      if File.exists?(path)
        file_config = from_yaml(File.read(path))
        config = config.merge(file_config)
      end
    end

    # Environment variables override (highest priority)
    if env_server = ENV["SELLIA_SERVER"]?
      config.server = env_server
    end
    if env_key = ENV["SELLIA_API_KEY"]?
      config.api_key = env_key
    end

    config
  end
end
```

**Responsibilities:**
- Load configuration from multiple sources with proper merging
- Support YAML config files
- Support environment variable overrides
- Validate configuration

## Commands

**Location:** `src/cli/main.cr`

The CLI uses OptionParser directly for command parsing, not a separate command library.

### Main Entry Point

```crystal
module Sellia::CLI
  def self.run
    ::Log.setup_from_env(default_level: :warn)

    command = ARGV.shift?

    case command
    when "http"
      run_http_tunnel
    when "start"
      run_start
    when "auth"
      run_auth
    when "admin"
      run_admin
    when "update"
      run_update
    when "version", "-v", "--version"
      puts "Sellia v#{Sellia::VERSION}"
    else
      # Show help
    end
  end
end
```

### HTTP Command

Create HTTP tunnel to local port.

**Options:**
- `--subdomain NAME, -s NAME` - Request specific subdomain
- `--auth USER:PASS, -a USER:PASS` - Enable basic auth protection
- `--host HOST, -H HOST` - Local host (default: localhost)
- `--server URL` - Tunnel server URL
- `--api-key KEY, -k KEY` - API key for authentication
- `--inspector-port PORT, -i PORT` - Inspector UI port (default: 4040)
- `--open, -o` - Open inspector in browser on connect
- `--no-inspector` - Disable the request inspector

### Start Command

Start tunnels from config file.

**Options:**
- `--config FILE, -c FILE` - Config file path

### Auth Command

Manage authentication.

**Subcommands:**
- `login` - Save API key for authentication
- `logout` - Remove saved API key
- `status` - Show current authentication status

## Reconnection Logic

### Linear Backoff

```crystal
class Sellia::CLI::TunnelClient
  property auto_reconnect : Bool = true
  property reconnect_delay : Time::Span = 3.seconds
  property max_reconnect_attempts : Int32 = 10

  private def handle_reconnect
    return unless @running && @auto_reconnect

    @reconnect_attempts += 1

    if @reconnect_attempts > @max_reconnect_attempts
      Log.error { "Max reconnection attempts exceeded" }
      @running = false
      return
    end

    delay = @reconnect_delay * @reconnect_attempts  # Linear backoff
    Log.info { "Reconnecting in #{delay.total_seconds.to_i}s..." }

    sleep delay
    connect if @running
  end
end
```

## Message Handling

### Binary WebSocket Messages

The client uses MessagePack for binary message serialization:

```crystal
private def handle_message(bytes : Bytes)
  message = Protocol::Message.from_msgpack(bytes)

  case message
  when Protocol::Messages::AuthOk
    handle_auth_ok(message)
  when Protocol::Messages::AuthError
    handle_auth_error(message)
  when Protocol::Messages::TunnelReady
    handle_tunnel_ready(message)
  when Protocol::Messages::TunnelClose
    handle_tunnel_close(message)
  when Protocol::Messages::RequestStart
    handle_request_start(message)
  when Protocol::Messages::RequestBody
    handle_request_body(message)
  when Protocol::Messages::Ping
    send_message(Protocol::Messages::Pong.new(message.timestamp))
  when Protocol::Messages::WebSocketUpgrade
    handle_websocket_upgrade(message)
  # ... more message types
  end
end
```

### Sending Messages

```crystal
private def send_message(message : Protocol::Message)
  socket = @socket
  return unless socket && @running

  @send_mutex.synchronize do
    socket.send(message.to_msgpack)
  end
end
```

The mutex prevents concurrent writes from multiple request handler fibers.

## Performance

### Concurrent Request Handling

Each incoming request spawns a fiber for parallel processing:

```crystal
private def handle_request_body(message : Protocol::Messages::RequestBody)
  body_io = @request_bodies[message.request_id]?
  return unless body_io

  body_io.write(message.chunk) unless message.chunk.empty?

  if message.final
    # Request body complete - forward to local service
    spawn do
      forward_request(message.request_id)
    end
  end
end
```

### Memory

- Per pending request: ~10KB (headers + body buffer)
- Per WebSocket: ~10KB (frame buffer)
- Inspector storage: Configurable (default 1000 requests)

## Debugging

### Logging

```crystal
Log.setup_from_env(default_level: :warn)

Log.debug { "Connecting to #{@server_url}" }
Log.info { "Tunnel ready: #{url}" }
Log.warn { "Tunnel closed by server: #{reason}" }
Log.error { "Connection failed: #{ex.message}" }
```

### Debug Mode

```bash
# Enable debug logging
LOG_LEVEL=debug sellia http 3000

# Enable trace logging
LOG_LEVEL=trace sellia http 3000
```

## See Also

- [TunnelClient Details](./tunnel-client.md) - Detailed TunnelClient documentation
- [Inspector Documentation](./inspector.md) - Inspector component details
- [LocalProxy Documentation](./local-proxy.md) - Local proxy implementation
- [Router Documentation](./router.md) - Request routing
- [Updater Documentation](./updater.md) - Self-update functionality
