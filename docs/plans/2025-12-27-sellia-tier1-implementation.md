# Sellia Tier 1 MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a working tunnel server and CLI that can expose local HTTP services to the internet with custom subdomains, request inspection, and basic auth.

**Architecture:** WebSocket-based protocol using MessagePack serialization. Server handles HTTP ingress and routes to connected clients via multiplexed WebSocket. CLI proxies requests to local services and runs an embedded React inspector UI.

**Tech Stack:** Crystal 1.10+, MessagePack (msgpack-crystal), SQLite (crystal-sqlite3), React 18, Vite 5, Tailwind CSS v4

---

## Phase 1: Project Structure & Core Protocol

### Task 1: Set Up Project Structure

**Files:**
- Create: `src/core/sellia.cr`
- Create: `src/core/version.cr`
- Create: `src/server/main.cr`
- Create: `src/cli/main.cr`
- Modify: `shard.yml`
- Modify: `src/sellia.cr`

**Step 1: Update shard.yml with dependencies and targets**

```yaml
name: sellia
version: 0.1.0
license: MIT

authors:
  - Chris Watson <chris@watzon.me>

crystal: ">= 1.10.0"

dependencies:
  msgpack:
    github: crystal-community/msgpack-crystal
  sqlite3:
    github: crystal-lang/crystal-sqlite3
  option_parser:
    github: crystal-lang/crystal # stdlib

targets:
  sellia:
    main: src/cli/main.cr
  sellia-server:
    main: src/server/main.cr

development_dependencies:
  spectator:
    github: icy-arctic-fox/spectator
```

**Step 2: Create core module structure**

Create `src/core/sellia.cr`:
```crystal
module Sellia
  # Core shared code between server and CLI
end
```

Create `src/core/version.cr`:
```crystal
module Sellia
  VERSION = "0.1.0"
end
```

**Step 3: Create server entrypoint**

Create `src/server/main.cr`:
```crystal
require "../core/sellia"
require "../core/version"

module Sellia::Server
  def self.run
    puts "Sellia Server v#{Sellia::VERSION}"
    puts "Starting server..."
  end
end

Sellia::Server.run
```

**Step 4: Create CLI entrypoint**

Create `src/cli/main.cr`:
```crystal
require "../core/sellia"
require "../core/version"

module Sellia::CLI
  def self.run
    puts "Sellia CLI v#{Sellia::VERSION}"
  end
end

Sellia::CLI.run
```

**Step 5: Update main sellia.cr to require core**

Replace `src/sellia.cr`:
```crystal
require "./core/sellia"
require "./core/version"
```

**Step 6: Verify builds work**

Run: `shards install && shards build`
Expected: Both `bin/sellia` and `bin/sellia-server` created

Run: `bin/sellia`
Expected: "Sellia CLI v0.1.0"

Run: `bin/sellia-server`
Expected: "Sellia Server v0.1.0" and "Starting server..."

**Step 7: Commit**

```bash
git add -A
git commit -m "chore: Set up monorepo structure with server and CLI targets"
```

---

### Task 2: Define Protocol Messages

**Files:**
- Create: `src/core/protocol/message.cr`
- Create: `src/core/protocol/messages/auth.cr`
- Create: `src/core/protocol/messages/tunnel.cr`
- Create: `src/core/protocol/messages/request.cr`
- Create: `src/core/protocol.cr`
- Create: `spec/core/protocol/message_spec.cr`

**Step 1: Write failing test for message serialization**

Create `spec/core/protocol/message_spec.cr`:
```crystal
require "../../spec_helper"
require "../../../src/core/protocol"

describe Sellia::Protocol::Message do
  describe ".from_msgpack" do
    it "deserializes an auth message" do
      msg = Sellia::Protocol::Messages::Auth.new(api_key: "sk_test_123")
      packed = msg.to_msgpack

      unpacked = Sellia::Protocol::Message.from_msgpack(packed)
      unpacked.should be_a(Sellia::Protocol::Messages::Auth)
      unpacked.as(Sellia::Protocol::Messages::Auth).api_key.should eq("sk_test_123")
    end
  end
end

describe Sellia::Protocol::Messages::Auth do
  it "serializes to msgpack with type field" do
    msg = Sellia::Protocol::Messages::Auth.new(api_key: "sk_test_123")
    packed = msg.to_msgpack

    unpacker = MessagePack::Unpacker.new(packed)
    hash = unpacker.read
    hash.as(Hash)["type"].should eq("auth")
    hash.as(Hash)["api_key"].should eq("sk_test_123")
  end
end
```

Update `spec/spec_helper.cr`:
```crystal
require "spectator"
require "msgpack"

Spectator.configure do |config|
  config.fail_blank
end
```

**Step 2: Run test to verify it fails**

Run: `crystal spec spec/core/protocol/message_spec.cr`
Expected: FAIL - cannot find Protocol module

**Step 3: Implement base message class**

Create `src/core/protocol/message.cr`:
```crystal
require "msgpack"

module Sellia::Protocol
  # Base class for all protocol messages
  abstract class Message
    include MessagePack::Serializable

    # Type discriminator for polymorphic deserialization
    abstract def type : String

    # Serialize with type field included
    def to_msgpack : Bytes
      io = IO::Memory.new
      packer = MessagePack::Packer.new(io)

      hash = to_hash
      hash["type"] = type
      packer.write(hash)

      io.to_slice
    end

    # Convert message fields to hash (for serialization)
    abstract def to_hash : Hash(String, MessagePack::Type)

    # Deserialize from msgpack bytes
    def self.from_msgpack(bytes : Bytes) : Message
      unpacker = MessagePack::Unpacker.new(bytes)
      hash = unpacker.read.as(Hash)
      type = hash["type"].as(String)

      case type
      when "auth"
        Messages::Auth.from_hash(hash)
      when "auth_ok"
        Messages::AuthOk.from_hash(hash)
      when "auth_error"
        Messages::AuthError.from_hash(hash)
      when "tunnel_open"
        Messages::TunnelOpen.from_hash(hash)
      when "tunnel_ready"
        Messages::TunnelReady.from_hash(hash)
      when "tunnel_close"
        Messages::TunnelClose.from_hash(hash)
      when "request_start"
        Messages::RequestStart.from_hash(hash)
      when "request_body"
        Messages::RequestBody.from_hash(hash)
      when "response_start"
        Messages::ResponseStart.from_hash(hash)
      when "response_body"
        Messages::ResponseBody.from_hash(hash)
      when "response_end"
        Messages::ResponseEnd.from_hash(hash)
      when "ping"
        Messages::Ping.from_hash(hash)
      when "pong"
        Messages::Pong.from_hash(hash)
      else
        raise "Unknown message type: #{type}"
      end
    end
  end
end
```

**Step 4: Implement auth messages**

Create `src/core/protocol/messages/auth.cr`:
```crystal
module Sellia::Protocol::Messages
  class Auth < Message
    property api_key : String

    def initialize(@api_key : String)
    end

    def type : String
      "auth"
    end

    def to_hash : Hash(String, MessagePack::Type)
      {
        "api_key" => @api_key.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : Auth
      new(api_key: hash["api_key"].as(String))
    end
  end

  class AuthOk < Message
    property account_id : String
    property limits : Hash(String, Int64)

    def initialize(@account_id : String, @limits : Hash(String, Int64) = {} of String => Int64)
    end

    def type : String
      "auth_ok"
    end

    def to_hash : Hash(String, MessagePack::Type)
      limits_typed = {} of String => MessagePack::Type
      @limits.each { |k, v| limits_typed[k] = v.as(MessagePack::Type) }
      {
        "account_id" => @account_id.as(MessagePack::Type),
        "limits" => limits_typed.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : AuthOk
      limits = {} of String => Int64
      if hash_limits = hash["limits"]?
        hash_limits.as(Hash).each do |k, v|
          limits[k.as(String)] = v.as(Int64)
        end
      end
      new(account_id: hash["account_id"].as(String), limits: limits)
    end
  end

  class AuthError < Message
    property error : String

    def initialize(@error : String)
    end

    def type : String
      "auth_error"
    end

    def to_hash : Hash(String, MessagePack::Type)
      {
        "error" => @error.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : AuthError
      new(error: hash["error"].as(String))
    end
  end
end
```

**Step 5: Implement tunnel messages**

Create `src/core/protocol/messages/tunnel.cr`:
```crystal
module Sellia::Protocol::Messages
  class TunnelOpen < Message
    property tunnel_type : String  # "http" or "tcp"
    property subdomain : String?
    property local_port : Int32
    property auth : String?  # "user:pass" for basic auth

    def initialize(@tunnel_type : String, @local_port : Int32, @subdomain : String? = nil, @auth : String? = nil)
    end

    def type : String
      "tunnel_open"
    end

    def to_hash : Hash(String, MessagePack::Type)
      hash = {
        "tunnel_type" => @tunnel_type.as(MessagePack::Type),
        "local_port" => @local_port.to_i64.as(MessagePack::Type)
      } of String => MessagePack::Type
      hash["subdomain"] = @subdomain.as(MessagePack::Type) if @subdomain
      hash["auth"] = @auth.as(MessagePack::Type) if @auth
      hash
    end

    def self.from_hash(hash : Hash) : TunnelOpen
      new(
        tunnel_type: hash["tunnel_type"].as(String),
        local_port: hash["local_port"].as(Int64).to_i32,
        subdomain: hash["subdomain"]?.try(&.as(String)),
        auth: hash["auth"]?.try(&.as(String))
      )
    end
  end

  class TunnelReady < Message
    property tunnel_id : String
    property url : String
    property subdomain : String

    def initialize(@tunnel_id : String, @url : String, @subdomain : String)
    end

    def type : String
      "tunnel_ready"
    end

    def to_hash : Hash(String, MessagePack::Type)
      {
        "tunnel_id" => @tunnel_id.as(MessagePack::Type),
        "url" => @url.as(MessagePack::Type),
        "subdomain" => @subdomain.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : TunnelReady
      new(
        tunnel_id: hash["tunnel_id"].as(String),
        url: hash["url"].as(String),
        subdomain: hash["subdomain"].as(String)
      )
    end
  end

  class TunnelClose < Message
    property tunnel_id : String
    property reason : String?

    def initialize(@tunnel_id : String, @reason : String? = nil)
    end

    def type : String
      "tunnel_close"
    end

    def to_hash : Hash(String, MessagePack::Type)
      hash = {
        "tunnel_id" => @tunnel_id.as(MessagePack::Type)
      } of String => MessagePack::Type
      hash["reason"] = @reason.as(MessagePack::Type) if @reason
      hash
    end

    def self.from_hash(hash : Hash) : TunnelClose
      new(
        tunnel_id: hash["tunnel_id"].as(String),
        reason: hash["reason"]?.try(&.as(String))
      )
    end
  end
end
```

**Step 6: Implement request/response messages**

Create `src/core/protocol/messages/request.cr`:
```crystal
module Sellia::Protocol::Messages
  class RequestStart < Message
    property request_id : String
    property tunnel_id : String
    property method : String
    property path : String
    property headers : Hash(String, String)

    def initialize(@request_id : String, @tunnel_id : String, @method : String, @path : String, @headers : Hash(String, String))
    end

    def type : String
      "request_start"
    end

    def to_hash : Hash(String, MessagePack::Type)
      headers_typed = {} of String => MessagePack::Type
      @headers.each { |k, v| headers_typed[k] = v.as(MessagePack::Type) }
      {
        "request_id" => @request_id.as(MessagePack::Type),
        "tunnel_id" => @tunnel_id.as(MessagePack::Type),
        "method" => @method.as(MessagePack::Type),
        "path" => @path.as(MessagePack::Type),
        "headers" => headers_typed.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : RequestStart
      headers = {} of String => String
      hash["headers"].as(Hash).each do |k, v|
        headers[k.as(String)] = v.as(String)
      end
      new(
        request_id: hash["request_id"].as(String),
        tunnel_id: hash["tunnel_id"].as(String),
        method: hash["method"].as(String),
        path: hash["path"].as(String),
        headers: headers
      )
    end
  end

  class RequestBody < Message
    property request_id : String
    property chunk : Bytes
    property final : Bool

    def initialize(@request_id : String, @chunk : Bytes, @final : Bool = false)
    end

    def type : String
      "request_body"
    end

    def to_hash : Hash(String, MessagePack::Type)
      {
        "request_id" => @request_id.as(MessagePack::Type),
        "chunk" => @chunk.as(MessagePack::Type),
        "final" => @final.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : RequestBody
      new(
        request_id: hash["request_id"].as(String),
        chunk: hash["chunk"].as(Bytes),
        final: hash["final"].as(Bool)
      )
    end
  end

  class ResponseStart < Message
    property request_id : String
    property status_code : Int32
    property headers : Hash(String, String)

    def initialize(@request_id : String, @status_code : Int32, @headers : Hash(String, String))
    end

    def type : String
      "response_start"
    end

    def to_hash : Hash(String, MessagePack::Type)
      headers_typed = {} of String => MessagePack::Type
      @headers.each { |k, v| headers_typed[k] = v.as(MessagePack::Type) }
      {
        "request_id" => @request_id.as(MessagePack::Type),
        "status_code" => @status_code.to_i64.as(MessagePack::Type),
        "headers" => headers_typed.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : ResponseStart
      headers = {} of String => String
      hash["headers"].as(Hash).each do |k, v|
        headers[k.as(String)] = v.as(String)
      end
      new(
        request_id: hash["request_id"].as(String),
        status_code: hash["status_code"].as(Int64).to_i32,
        headers: headers
      )
    end
  end

  class ResponseBody < Message
    property request_id : String
    property chunk : Bytes

    def initialize(@request_id : String, @chunk : Bytes)
    end

    def type : String
      "response_body"
    end

    def to_hash : Hash(String, MessagePack::Type)
      {
        "request_id" => @request_id.as(MessagePack::Type),
        "chunk" => @chunk.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : ResponseBody
      new(
        request_id: hash["request_id"].as(String),
        chunk: hash["chunk"].as(Bytes)
      )
    end
  end

  class ResponseEnd < Message
    property request_id : String

    def initialize(@request_id : String)
    end

    def type : String
      "response_end"
    end

    def to_hash : Hash(String, MessagePack::Type)
      {
        "request_id" => @request_id.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : ResponseEnd
      new(request_id: hash["request_id"].as(String))
    end
  end

  class Ping < Message
    property timestamp : Int64

    def initialize(@timestamp : Int64 = Time.utc.to_unix_ms)
    end

    def type : String
      "ping"
    end

    def to_hash : Hash(String, MessagePack::Type)
      {
        "timestamp" => @timestamp.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : Ping
      new(timestamp: hash["timestamp"].as(Int64))
    end
  end

  class Pong < Message
    property timestamp : Int64

    def initialize(@timestamp : Int64 = Time.utc.to_unix_ms)
    end

    def type : String
      "pong"
    end

    def to_hash : Hash(String, MessagePack::Type)
      {
        "timestamp" => @timestamp.as(MessagePack::Type)
      }
    end

    def self.from_hash(hash : Hash) : Pong
      new(timestamp: hash["timestamp"].as(Int64))
    end
  end
end
```

**Step 7: Create protocol entry point**

Create `src/core/protocol.cr`:
```crystal
require "./protocol/message"
require "./protocol/messages/auth"
require "./protocol/messages/tunnel"
require "./protocol/messages/request"

module Sellia::Protocol
  # Re-export for convenience
  alias Auth = Messages::Auth
  alias AuthOk = Messages::AuthOk
  alias AuthError = Messages::AuthError
  alias TunnelOpen = Messages::TunnelOpen
  alias TunnelReady = Messages::TunnelReady
  alias TunnelClose = Messages::TunnelClose
  alias RequestStart = Messages::RequestStart
  alias RequestBody = Messages::RequestBody
  alias ResponseStart = Messages::ResponseStart
  alias ResponseBody = Messages::ResponseBody
  alias ResponseEnd = Messages::ResponseEnd
  alias Ping = Messages::Ping
  alias Pong = Messages::Pong
end
```

**Step 8: Run tests to verify they pass**

Run: `crystal spec spec/core/protocol/message_spec.cr`
Expected: PASS

**Step 9: Add more comprehensive tests**

Add to `spec/core/protocol/message_spec.cr`:
```crystal
describe Sellia::Protocol::Messages::TunnelOpen do
  it "round-trips through msgpack" do
    original = Sellia::Protocol::Messages::TunnelOpen.new(
      tunnel_type: "http",
      local_port: 3000,
      subdomain: "myapp",
      auth: "user:pass"
    )

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    unpacked.should be_a(Sellia::Protocol::Messages::TunnelOpen)
    msg = unpacked.as(Sellia::Protocol::Messages::TunnelOpen)
    msg.tunnel_type.should eq("http")
    msg.local_port.should eq(3000)
    msg.subdomain.should eq("myapp")
    msg.auth.should eq("user:pass")
  end
end

describe Sellia::Protocol::Messages::RequestStart do
  it "round-trips headers correctly" do
    original = Sellia::Protocol::Messages::RequestStart.new(
      request_id: "req-123",
      tunnel_id: "tun-456",
      method: "POST",
      path: "/api/users",
      headers: {"Content-Type" => "application/json", "X-Custom" => "value"}
    )

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::RequestStart)
    msg.headers["Content-Type"].should eq("application/json")
    msg.headers["X-Custom"].should eq("value")
  end
end
```

**Step 10: Run all tests**

Run: `crystal spec`
Expected: All tests PASS

**Step 11: Commit**

```bash
git add -A
git commit -m "feat(core): Implement MessagePack protocol messages

Add message types for:
- Auth flow (auth, auth_ok, auth_error)
- Tunnel management (tunnel_open, tunnel_ready, tunnel_close)
- Request proxying (request_start, request_body, response_start, response_body, response_end)
- Keepalive (ping, pong)"
```

---

## Phase 2: Server Implementation

### Task 3: Implement Tunnel Registry

**Files:**
- Create: `src/server/tunnel_registry.cr`
- Create: `spec/server/tunnel_registry_spec.cr`

**Step 1: Write failing test**

Create `spec/server/tunnel_registry_spec.cr`:
```crystal
require "../spec_helper"
require "../../src/server/tunnel_registry"

describe Sellia::Server::TunnelRegistry do
  describe "#register" do
    it "registers a tunnel with a subdomain" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456"
      )

      registry.register(tunnel)
      registry.find_by_subdomain("myapp").should eq(tunnel)
    end

    it "returns nil for unknown subdomain" do
      registry = Sellia::Server::TunnelRegistry.new
      registry.find_by_subdomain("unknown").should be_nil
    end
  end

  describe "#unregister" do
    it "removes a tunnel" do
      registry = Sellia::Server::TunnelRegistry.new
      tunnel = Sellia::Server::TunnelRegistry::Tunnel.new(
        id: "tun-123",
        subdomain: "myapp",
        client_id: "client-456"
      )

      registry.register(tunnel)
      registry.unregister(tunnel.id)
      registry.find_by_subdomain("myapp").should be_nil
    end
  end

  describe "#generate_subdomain" do
    it "generates a unique subdomain" do
      registry = Sellia::Server::TunnelRegistry.new
      sub1 = registry.generate_subdomain
      sub2 = registry.generate_subdomain

      sub1.should_not eq(sub2)
      sub1.size.should be >= 6
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `crystal spec spec/server/tunnel_registry_spec.cr`
Expected: FAIL - cannot find TunnelRegistry

**Step 3: Implement TunnelRegistry**

Create `src/server/tunnel_registry.cr`:
```crystal
require "mutex"

module Sellia::Server
  class TunnelRegistry
    struct Tunnel
      property id : String
      property subdomain : String
      property client_id : String
      property created_at : Time
      property auth : String?

      def initialize(@id : String, @subdomain : String, @client_id : String, @auth : String? = nil)
        @created_at = Time.utc
      end
    end

    def initialize
      @tunnels = {} of String => Tunnel       # id -> tunnel
      @by_subdomain = {} of String => Tunnel  # subdomain -> tunnel
      @by_client = {} of String => Array(Tunnel)  # client_id -> tunnels
      @mutex = Mutex.new
    end

    def register(tunnel : Tunnel) : Nil
      @mutex.synchronize do
        @tunnels[tunnel.id] = tunnel
        @by_subdomain[tunnel.subdomain] = tunnel

        @by_client[tunnel.client_id] ||= [] of Tunnel
        @by_client[tunnel.client_id] << tunnel
      end
    end

    def unregister(tunnel_id : String) : Tunnel?
      @mutex.synchronize do
        if tunnel = @tunnels.delete(tunnel_id)
          @by_subdomain.delete(tunnel.subdomain)

          if client_tunnels = @by_client[tunnel.client_id]?
            client_tunnels.reject! { |t| t.id == tunnel_id }
            @by_client.delete(tunnel.client_id) if client_tunnels.empty?
          end

          tunnel
        end
      end
    end

    def find_by_id(id : String) : Tunnel?
      @mutex.synchronize { @tunnels[id]? }
    end

    def find_by_subdomain(subdomain : String) : Tunnel?
      @mutex.synchronize { @by_subdomain[subdomain]? }
    end

    def find_by_client(client_id : String) : Array(Tunnel)
      @mutex.synchronize { @by_client[client_id]? || [] of Tunnel }
    end

    def subdomain_available?(subdomain : String) : Bool
      @mutex.synchronize { !@by_subdomain.has_key?(subdomain) }
    end

    def generate_subdomain : String
      loop do
        # Generate random 8-char subdomain
        subdomain = Random::Secure.hex(4)
        return subdomain if subdomain_available?(subdomain)
      end
    end

    def size : Int32
      @mutex.synchronize { @tunnels.size }
    end

    def unregister_client(client_id : String) : Array(Tunnel)
      @mutex.synchronize do
        removed = [] of Tunnel
        if tunnels = @by_client.delete(client_id)
          tunnels.each do |tunnel|
            @tunnels.delete(tunnel.id)
            @by_subdomain.delete(tunnel.subdomain)
            removed << tunnel
          end
        end
        removed
      end
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `crystal spec spec/server/tunnel_registry_spec.cr`
Expected: All PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(server): Add TunnelRegistry for managing active tunnels"
```

---

### Task 4: Implement Client Connection Manager

**Files:**
- Create: `src/server/client_connection.cr`
- Create: `src/server/connection_manager.cr`
- Create: `spec/server/connection_manager_spec.cr`

**Step 1: Write failing test**

Create `spec/server/connection_manager_spec.cr`:
```crystal
require "../spec_helper"
require "../../src/server/connection_manager"

describe Sellia::Server::ConnectionManager do
  describe "#register" do
    it "registers a client connection" do
      manager = Sellia::Server::ConnectionManager.new

      client_id = manager.register("api_key_123")
      client_id.should_not be_nil
      manager.authenticated?("api_key_123").should be_true
    end
  end

  describe "#unregister" do
    it "removes a client connection" do
      manager = Sellia::Server::ConnectionManager.new

      client_id = manager.register("api_key_123")
      manager.unregister(client_id)
      manager.find(client_id).should be_nil
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `crystal spec spec/server/connection_manager_spec.cr`
Expected: FAIL - cannot find ConnectionManager

**Step 3: Implement ClientConnection**

Create `src/server/client_connection.cr`:
```crystal
require "http/web_socket"
require "../core/protocol"

module Sellia::Server
  class ClientConnection
    property id : String
    property api_key : String?
    property socket : HTTP::WebSocket
    property authenticated : Bool
    property created_at : Time

    @message_handler : (Protocol::Message -> Nil)?
    @close_handler : (-> Nil)?

    def initialize(@socket : HTTP::WebSocket, @id : String = Random::Secure.hex(16))
      @authenticated = false
      @created_at = Time.utc

      setup_handlers
    end

    private def setup_handlers
      @socket.on_binary do |bytes|
        begin
          message = Protocol::Message.from_msgpack(bytes)
          @message_handler.try(&.call(message))
        rescue ex
          # Log parse error but don't crash
          puts "Failed to parse message: #{ex.message}"
        end
      end

      @socket.on_close do
        @close_handler.try(&.call)
      end
    end

    def on_message(&handler : Protocol::Message -> Nil)
      @message_handler = handler
    end

    def on_close(&handler : -> Nil)
      @close_handler = handler
    end

    def send(message : Protocol::Message)
      @socket.send(message.to_msgpack)
    end

    def close(reason : String? = nil)
      @socket.close(reason || "Connection closed")
    rescue
      # Socket may already be closed
    end

    def run
      @socket.run
    end
  end
end
```

**Step 4: Implement ConnectionManager**

Create `src/server/connection_manager.cr`:
```crystal
require "mutex"
require "./client_connection"

module Sellia::Server
  class ConnectionManager
    def initialize
      @connections = {} of String => ClientConnection
      @by_api_key = {} of String => String  # api_key -> client_id
      @mutex = Mutex.new
    end

    def register(api_key : String, connection : ClientConnection? = nil) : String
      @mutex.synchronize do
        client_id = connection.try(&.id) || Random::Secure.hex(16)

        if connection
          @connections[client_id] = connection
          connection.authenticated = true
          connection.api_key = api_key
        end

        @by_api_key[api_key] = client_id
        client_id
      end
    end

    def add_connection(connection : ClientConnection) : Nil
      @mutex.synchronize do
        @connections[connection.id] = connection
      end
    end

    def unregister(client_id : String) : ClientConnection?
      @mutex.synchronize do
        if conn = @connections.delete(client_id)
          @by_api_key.delete(conn.api_key) if conn.api_key
          conn
        end
      end
    end

    def find(client_id : String) : ClientConnection?
      @mutex.synchronize { @connections[client_id]? }
    end

    def find_by_api_key(api_key : String) : ClientConnection?
      @mutex.synchronize do
        if client_id = @by_api_key[api_key]?
          @connections[client_id]?
        end
      end
    end

    def authenticated?(api_key : String) : Bool
      @mutex.synchronize { @by_api_key.has_key?(api_key) }
    end

    def size : Int32
      @mutex.synchronize { @connections.size }
    end

    def broadcast(message : Protocol::Message)
      @mutex.synchronize do
        @connections.each_value do |conn|
          conn.send(message) if conn.authenticated
        end
      end
    end
  end
end
```

**Step 5: Run tests**

Run: `crystal spec spec/server/connection_manager_spec.cr`
Expected: All PASS

**Step 6: Commit**

```bash
git add -A
git commit -m "feat(server): Add ClientConnection and ConnectionManager"
```

---

### Task 5: Implement WebSocket Gateway

**Files:**
- Create: `src/server/ws_gateway.cr`
- Create: `src/server/auth_provider.cr`

**Step 1: Implement AuthProvider (simple API key validation)**

Create `src/server/auth_provider.cr`:
```crystal
module Sellia::Server
  # Simple auth provider - validates API keys
  # In Tier 1, we support a single master key or no auth (for self-hosted)
  class AuthProvider
    property require_auth : Bool
    property master_key : String?

    def initialize(@require_auth : Bool = false, @master_key : String? = nil)
    end

    def validate(api_key : String) : Bool
      return true unless @require_auth
      return false if api_key.empty?

      if master = @master_key
        api_key == master
      else
        # No master key configured - accept any non-empty key
        true
      end
    end

    def account_id_for(api_key : String) : String
      # Simple implementation - hash the key
      Digest::SHA256.hexdigest(api_key)[0, 16]
    end
  end
end

require "digest/sha256"
```

**Step 2: Implement WebSocket Gateway**

Create `src/server/ws_gateway.cr`:
```crystal
require "http/web_socket"
require "./client_connection"
require "./connection_manager"
require "./tunnel_registry"
require "./auth_provider"
require "../core/protocol"

module Sellia::Server
  class WSGateway
    property connection_manager : ConnectionManager
    property tunnel_registry : TunnelRegistry
    property auth_provider : AuthProvider
    property domain : String
    property use_https : Bool

    def initialize(
      @connection_manager : ConnectionManager,
      @tunnel_registry : TunnelRegistry,
      @auth_provider : AuthProvider,
      @domain : String = "localhost",
      @use_https : Bool = false
    )
    end

    def handle(socket : HTTP::WebSocket)
      client = ClientConnection.new(socket)
      @connection_manager.add_connection(client)

      puts "[WS] Client connected: #{client.id}"

      client.on_message do |message|
        handle_message(client, message)
      end

      client.on_close do
        handle_disconnect(client)
      end

      client.run
    end

    private def handle_message(client : ClientConnection, message : Protocol::Message)
      case message
      when Protocol::Messages::Auth
        handle_auth(client, message)
      when Protocol::Messages::TunnelOpen
        handle_tunnel_open(client, message)
      when Protocol::Messages::TunnelClose
        handle_tunnel_close(client, message)
      when Protocol::Messages::ResponseStart
        handle_response_start(client, message)
      when Protocol::Messages::ResponseBody
        handle_response_body(client, message)
      when Protocol::Messages::ResponseEnd
        handle_response_end(client, message)
      when Protocol::Messages::Ping
        client.send(Protocol::Messages::Pong.new(message.timestamp))
      end
    end

    private def handle_auth(client : ClientConnection, message : Protocol::Messages::Auth)
      if @auth_provider.validate(message.api_key)
        client.authenticated = true
        client.api_key = message.api_key

        account_id = @auth_provider.account_id_for(message.api_key)
        client.send(Protocol::Messages::AuthOk.new(
          account_id: account_id,
          limits: {"max_tunnels" => 10_i64, "max_connections" => 100_i64}
        ))

        puts "[WS] Client authenticated: #{client.id}"
      else
        client.send(Protocol::Messages::AuthError.new("Invalid API key"))
        client.close("Authentication failed")
      end
    end

    private def handle_tunnel_open(client : ClientConnection, message : Protocol::Messages::TunnelOpen)
      unless client.authenticated
        client.send(Protocol::Messages::AuthError.new("Not authenticated"))
        return
      end

      # Determine subdomain
      subdomain = message.subdomain
      if subdomain.nil? || subdomain.empty?
        subdomain = @tunnel_registry.generate_subdomain
      elsif !@tunnel_registry.subdomain_available?(subdomain)
        client.send(Protocol::Messages::TunnelClose.new(
          tunnel_id: "",
          reason: "Subdomain '#{subdomain}' is not available"
        ))
        return
      end

      # Create tunnel
      tunnel_id = Random::Secure.hex(16)
      tunnel = TunnelRegistry::Tunnel.new(
        id: tunnel_id,
        subdomain: subdomain,
        client_id: client.id,
        auth: message.auth
      )

      @tunnel_registry.register(tunnel)

      # Build public URL
      protocol = @use_https ? "https" : "http"
      url = "#{protocol}://#{subdomain}.#{@domain}"

      client.send(Protocol::Messages::TunnelReady.new(
        tunnel_id: tunnel_id,
        url: url,
        subdomain: subdomain
      ))

      puts "[WS] Tunnel opened: #{subdomain}.#{@domain} -> client #{client.id}"
    end

    private def handle_tunnel_close(client : ClientConnection, message : Protocol::Messages::TunnelClose)
      if tunnel = @tunnel_registry.find_by_id(message.tunnel_id)
        if tunnel.client_id == client.id
          @tunnel_registry.unregister(message.tunnel_id)
          puts "[WS] Tunnel closed: #{tunnel.subdomain}"
        end
      end
    end

    private def handle_response_start(client : ClientConnection, message : Protocol::Messages::ResponseStart)
      # Forward to pending request handler (implemented in HTTP ingress)
      # This is a stub - actual implementation connects to request tracking
    end

    private def handle_response_body(client : ClientConnection, message : Protocol::Messages::ResponseBody)
      # Forward body chunk to pending request
    end

    private def handle_response_end(client : ClientConnection, message : Protocol::Messages::ResponseEnd)
      # Complete the pending request
    end

    private def handle_disconnect(client : ClientConnection)
      puts "[WS] Client disconnected: #{client.id}"

      # Remove all tunnels for this client
      tunnels = @tunnel_registry.unregister_client(client.id)
      tunnels.each do |tunnel|
        puts "[WS] Tunnel removed: #{tunnel.subdomain}"
      end

      @connection_manager.unregister(client.id)
    end
  end
end
```

**Step 3: Commit**

```bash
git add -A
git commit -m "feat(server): Add WebSocket gateway with auth and tunnel handling"
```

---

### Task 6: Implement HTTP Ingress and Request Routing

**Files:**
- Create: `src/server/pending_request.cr`
- Create: `src/server/http_ingress.cr`
- Modify: `src/server/ws_gateway.cr`

**Step 1: Create PendingRequest for tracking in-flight requests**

Create `src/server/pending_request.cr`:
```crystal
require "http/server"

module Sellia::Server
  class PendingRequest
    property id : String
    property context : HTTP::Server::Context
    property tunnel_id : String
    property created_at : Time
    property response_started : Bool
    property channel : Channel(Nil)

    def initialize(@id : String, @context : HTTP::Server::Context, @tunnel_id : String)
      @created_at = Time.utc
      @response_started = false
      @channel = Channel(Nil).new
    end

    def start_response(status_code : Int32, headers : Hash(String, String))
      @response_started = true
      @context.response.status_code = status_code
      headers.each do |key, value|
        @context.response.headers[key] = value
      end
    end

    def write_body(chunk : Bytes)
      @context.response.write(chunk)
      @context.response.flush
    end

    def finish
      @context.response.close
      @channel.send(nil)
    end

    def wait(timeout : Time::Span = 30.seconds)
      select
      when @channel.receive
        true
      when timeout(timeout)
        false
      end
    end

    def error(status : Int32, message : String)
      @context.response.status_code = status
      @context.response.content_type = "text/plain"
      @context.response.print(message)
      @context.response.close
      @channel.send(nil)
    end
  end

  class PendingRequestStore
    def initialize
      @requests = {} of String => PendingRequest
      @mutex = Mutex.new
    end

    def add(request : PendingRequest)
      @mutex.synchronize { @requests[request.id] = request }
    end

    def get(id : String) : PendingRequest?
      @mutex.synchronize { @requests[id]? }
    end

    def remove(id : String) : PendingRequest?
      @mutex.synchronize { @requests.delete(id) }
    end
  end
end

require "mutex"
```

**Step 2: Create HTTP Ingress**

Create `src/server/http_ingress.cr`:
```crystal
require "http/server"
require "base64"
require "./tunnel_registry"
require "./connection_manager"
require "./pending_request"
require "../core/protocol"

module Sellia::Server
  class HTTPIngress
    property tunnel_registry : TunnelRegistry
    property connection_manager : ConnectionManager
    property pending_requests : PendingRequestStore
    property domain : String
    property request_timeout : Time::Span

    def initialize(
      @tunnel_registry : TunnelRegistry,
      @connection_manager : ConnectionManager,
      @pending_requests : PendingRequestStore,
      @domain : String = "localhost",
      @request_timeout : Time::Span = 30.seconds
    )
    end

    def handle(context : HTTP::Server::Context) : Nil
      request = context.request
      host = request.headers["Host"]?

      unless host
        context.response.status_code = 400
        context.response.print("Missing Host header")
        return
      end

      # Extract subdomain
      subdomain = extract_subdomain(host)

      unless subdomain
        # Root domain request - could serve API or info page
        serve_root(context)
        return
      end

      # Find tunnel for subdomain
      tunnel = @tunnel_registry.find_by_subdomain(subdomain)

      unless tunnel
        context.response.status_code = 404
        context.response.content_type = "text/plain"
        context.response.print("Tunnel not found: #{subdomain}")
        return
      end

      # Check basic auth if configured
      if tunnel.auth
        unless check_basic_auth(context, tunnel.auth.not_nil!)
          context.response.status_code = 401
          context.response.headers["WWW-Authenticate"] = "Basic realm=\"Tunnel\""
          context.response.print("Unauthorized")
          return
        end
      end

      # Find client connection
      client = @connection_manager.find(tunnel.client_id)

      unless client
        context.response.status_code = 502
        context.response.print("Tunnel client disconnected")
        return
      end

      # Proxy the request
      proxy_request(context, client, tunnel)
    end

    private def extract_subdomain(host : String) : String?
      # Remove port if present
      host = host.split(":").first

      # Check if it's a subdomain of our domain
      if host.ends_with?(".#{@domain}")
        host[0, host.size - @domain.size - 1]
      elsif host == @domain
        nil
      else
        # Could be custom domain in future
        nil
      end
    end

    private def serve_root(context : HTTP::Server::Context)
      if context.request.path == "/health"
        context.response.content_type = "application/json"
        context.response.print(%({"status":"ok","tunnels":#{@tunnel_registry.size}}))
      else
        context.response.content_type = "text/plain"
        context.response.print("Sellia Tunnel Server\n\nConnect with: sellia http <port>")
      end
    end

    private def check_basic_auth(context : HTTP::Server::Context, expected : String) : Bool
      auth_header = context.request.headers["Authorization"]?
      return false unless auth_header

      parts = auth_header.split(" ", 2)
      return false unless parts.size == 2 && parts[0].downcase == "basic"

      begin
        decoded = Base64.decode_string(parts[1])
        decoded == expected
      rescue
        false
      end
    end

    private def proxy_request(context : HTTP::Server::Context, client : ClientConnection, tunnel : TunnelRegistry::Tunnel)
      request_id = Random::Secure.hex(16)

      # Create pending request
      pending = PendingRequest.new(request_id, context, tunnel.id)
      @pending_requests.add(pending)

      # Build headers hash
      headers = {} of String => String
      context.request.headers.each do |key, values|
        headers[key] = values.first
      end

      # Send request start to client
      client.send(Protocol::Messages::RequestStart.new(
        request_id: request_id,
        tunnel_id: tunnel.id,
        method: context.request.method,
        path: context.request.resource,
        headers: headers
      ))

      # Send request body if present
      if body = context.request.body
        buffer = Bytes.new(8192)
        while (read = body.read(buffer)) > 0
          chunk = buffer[0, read].dup
          client.send(Protocol::Messages::RequestBody.new(
            request_id: request_id,
            chunk: chunk,
            final: false
          ))
        end
      end

      # Send final empty chunk to indicate end of request body
      client.send(Protocol::Messages::RequestBody.new(
        request_id: request_id,
        chunk: Bytes.empty,
        final: true
      ))

      # Wait for response with timeout
      unless pending.wait(@request_timeout)
        @pending_requests.remove(request_id)
        context.response.status_code = 504
        context.response.print("Gateway timeout - no response from tunnel")
      end

      @pending_requests.remove(request_id)
    end
  end
end
```

**Step 3: Update WSGateway to forward responses**

Update `src/server/ws_gateway.cr` - add pending_requests property and update response handlers:

Add to initialize:
```crystal
property pending_requests : PendingRequestStore
```

Update constructor:
```crystal
def initialize(
  @connection_manager : ConnectionManager,
  @tunnel_registry : TunnelRegistry,
  @auth_provider : AuthProvider,
  @pending_requests : PendingRequestStore,
  @domain : String = "localhost",
  @use_https : Bool = false
)
end
```

Update response handlers:
```crystal
private def handle_response_start(client : ClientConnection, message : Protocol::Messages::ResponseStart)
  if pending = @pending_requests.get(message.request_id)
    pending.start_response(message.status_code, message.headers)
  end
end

private def handle_response_body(client : ClientConnection, message : Protocol::Messages::ResponseBody)
  if pending = @pending_requests.get(message.request_id)
    pending.write_body(message.chunk) unless message.chunk.empty?
  end
end

private def handle_response_end(client : ClientConnection, message : Protocol::Messages::ResponseEnd)
  if pending = @pending_requests.get(message.request_id)
    pending.finish
  end
end
```

**Step 4: Commit**

```bash
git add -A
git commit -m "feat(server): Add HTTP ingress with request routing and proxying"
```

---

### Task 7: Wire Up Server Main Entry Point

**Files:**
- Modify: `src/server/main.cr`
- Create: `src/server/server.cr`

**Step 1: Create Server coordinator**

Create `src/server/server.cr`:
```crystal
require "http/server"
require "option_parser"
require "./tunnel_registry"
require "./connection_manager"
require "./pending_request"
require "./auth_provider"
require "./ws_gateway"
require "./http_ingress"
require "../core/version"

module Sellia::Server
  class Server
    property host : String
    property port : Int32
    property domain : String
    property require_auth : Bool
    property master_key : String?
    property use_https : Bool

    def initialize(
      @host : String = "0.0.0.0",
      @port : Int32 = 3000,
      @domain : String = "localhost",
      @require_auth : Bool = false,
      @master_key : String? = nil,
      @use_https : Bool = false
    )
      @tunnel_registry = TunnelRegistry.new
      @connection_manager = ConnectionManager.new
      @pending_requests = PendingRequestStore.new
      @auth_provider = AuthProvider.new(@require_auth, @master_key)

      @ws_gateway = WSGateway.new(
        connection_manager: @connection_manager,
        tunnel_registry: @tunnel_registry,
        auth_provider: @auth_provider,
        pending_requests: @pending_requests,
        domain: @domain,
        use_https: @use_https
      )

      @http_ingress = HTTPIngress.new(
        tunnel_registry: @tunnel_registry,
        connection_manager: @connection_manager,
        pending_requests: @pending_requests,
        domain: @domain
      )
    end

    def start
      server = HTTP::Server.new do |context|
        handle_request(context)
      end

      # Handle graceful shutdown
      Signal::INT.trap { shutdown(server) }
      Signal::TERM.trap { shutdown(server) }

      address = server.bind_tcp(@host, @port)
      puts "Sellia Server v#{Sellia::VERSION}"
      puts "Listening on http://#{address}"
      puts "Domain: #{@domain}"
      puts "Auth required: #{@require_auth}"
      puts ""
      puts "Press Ctrl+C to stop"

      server.listen
    end

    private def handle_request(context : HTTP::Server::Context)
      path = context.request.path

      # WebSocket upgrade for tunnel clients
      if path == "/ws" && context.request.headers["Upgrade"]?.try(&.downcase) == "websocket"
        ws_handler = HTTP::WebSocketHandler.new do |socket, ctx|
          @ws_gateway.handle(socket)
        end
        ws_handler.call(context)
      else
        # Regular HTTP - proxy to tunnel or serve root
        @http_ingress.handle(context)
      end
    end

    private def shutdown(server : HTTP::Server)
      puts "\nShutting down..."
      server.close
      exit 0
    end
  end

  def self.run
    host = ENV["SELLIA_HOST"]? || "0.0.0.0"
    port = (ENV["SELLIA_PORT"]? || "3000").to_i
    domain = ENV["SELLIA_DOMAIN"]? || "localhost"
    require_auth = ENV["SELLIA_REQUIRE_AUTH"]? == "true"
    master_key = ENV["SELLIA_MASTER_KEY"]?

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia-server [options]"

      parser.on("--host HOST", "Host to bind to (default: #{host})") { |h| host = h }
      parser.on("--port PORT", "Port to listen on (default: #{port})") { |p| port = p.to_i }
      parser.on("--domain DOMAIN", "Base domain for subdomains (default: #{domain})") { |d| domain = d }
      parser.on("--require-auth", "Require API key authentication") { require_auth = true }
      parser.on("--master-key KEY", "Master API key (enables auth)") { |k| master_key = k; require_auth = true }
      parser.on("-h", "--help", "Show this help") { puts parser; exit 0 }
      parser.on("-v", "--version", "Show version") { puts "Sellia Server v#{Sellia::VERSION}"; exit 0 }

      parser.invalid_option do |flag|
        STDERR.puts "Unknown option: #{flag}"
        STDERR.puts parser
        exit 1
      end
    end

    Server.new(
      host: host,
      port: port,
      domain: domain,
      require_auth: require_auth,
      master_key: master_key
    ).start
  end
end
```

**Step 2: Update main.cr**

Replace `src/server/main.cr`:
```crystal
require "./server"

Sellia::Server.run
```

**Step 3: Test server starts**

Run: `shards build && bin/sellia-server --help`
Expected: Help output with all options

Run: `bin/sellia-server --port 3001 &` then `curl http://localhost:3001/health`
Expected: `{"status":"ok","tunnels":0}`

Kill the server after testing.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat(server): Wire up complete server with CLI options"
```

---

## Phase 3: CLI Implementation

### Task 8: Implement CLI Configuration System

**Files:**
- Create: `src/cli/config.cr`
- Create: `spec/cli/config_spec.cr`

**Step 1: Write failing test**

Create `spec/cli/config_spec.cr`:
```crystal
require "../spec_helper"
require "../../src/cli/config"

describe Sellia::CLI::Config do
  describe ".load" do
    it "loads config from YAML string" do
      yaml = <<-YAML
      server: https://example.com
      api_key: sk_test_123
      inspector:
        port: 4040
      YAML

      config = Sellia::CLI::Config.from_yaml(yaml)
      config.server.should eq("https://example.com")
      config.api_key.should eq("sk_test_123")
      config.inspector.port.should eq(4040)
    end

    it "uses defaults for missing values" do
      config = Sellia::CLI::Config.new
      config.server.should eq("https://sellia.me")
      config.inspector.port.should eq(4040)
    end
  end

  describe "#merge" do
    it "merges two configs with later taking precedence" do
      base = Sellia::CLI::Config.from_yaml(<<-YAML)
      server: https://base.com
      api_key: base_key
      YAML

      overlay = Sellia::CLI::Config.from_yaml(<<-YAML)
      api_key: overlay_key
      YAML

      merged = base.merge(overlay)
      merged.server.should eq("https://base.com")
      merged.api_key.should eq("overlay_key")
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `crystal spec spec/cli/config_spec.cr`
Expected: FAIL

**Step 3: Implement Config**

Create `src/cli/config.cr`:
```crystal
require "yaml"

module Sellia::CLI
  class Config
    include YAML::Serializable

    class Inspector
      include YAML::Serializable

      property port : Int32 = 4040
      property open : Bool = false

      def initialize(@port : Int32 = 4040, @open : Bool = false)
      end

      def merge(other : Inspector) : Inspector
        Inspector.new(
          port: other.port != 4040 ? other.port : @port,
          open: other.open || @open
        )
      end
    end

    class TunnelConfig
      include YAML::Serializable

      property type : String = "http"
      property port : Int32
      property subdomain : String?
      property auth : String?
      property local_host : String = "localhost"

      def initialize(
        @port : Int32,
        @type : String = "http",
        @subdomain : String? = nil,
        @auth : String? = nil,
        @local_host : String = "localhost"
      )
      end
    end

    property server : String = "https://sellia.me"
    property api_key : String?
    property inspector : Inspector = Inspector.new
    property tunnels : Hash(String, TunnelConfig) = {} of String => TunnelConfig

    def initialize(
      @server : String = "https://sellia.me",
      @api_key : String? = nil,
      @inspector : Inspector = Inspector.new,
      @tunnels : Hash(String, TunnelConfig) = {} of String => TunnelConfig
    )
    end

    def merge(other : Config) : Config
      Config.new(
        server: other.server.empty? || other.server == "https://sellia.me" ? @server : other.server,
        api_key: other.api_key || @api_key,
        inspector: @inspector.merge(other.inspector),
        tunnels: @tunnels.merge(other.tunnels)
      )
    end

    # Load config from standard paths with merging
    def self.load : Config
      config = Config.new

      # Load in order of increasing priority
      paths = [
        Path.home / ".config" / "sellia" / "sellia.yml",
        Path.home / ".sellia.yml",
        Path.new("sellia.yml")
      ]

      paths.each do |path|
        if File.exists?(path)
          begin
            file_config = from_yaml(File.read(path))
            config = config.merge(file_config)
          rescue ex
            STDERR.puts "Warning: Failed to parse #{path}: #{ex.message}"
          end
        end
      end

      # Environment variables override
      if env_server = ENV["SELLIA_SERVER"]?
        config.server = env_server
      end
      if env_key = ENV["SELLIA_API_KEY"]?
        config.api_key = env_key
      end

      config
    end

    def self.from_yaml(yaml : String) : Config
      Config.from_yaml(yaml)
    end
  end
end
```

**Step 4: Run tests**

Run: `crystal spec spec/cli/config_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add -A
git commit -m "feat(cli): Add layered configuration system"
```

---

### Task 9: Implement Tunnel Client

**Files:**
- Create: `src/cli/tunnel_client.cr`
- Create: `src/cli/local_proxy.cr`

**Step 1: Implement LocalProxy for forwarding to local service**

Create `src/cli/local_proxy.cr`:
```crystal
require "http/client"
require "http/headers"

module Sellia::CLI
  class LocalProxy
    property host : String
    property port : Int32

    def initialize(@host : String = "localhost", @port : Int32 = 3000)
    end

    def forward(
      method : String,
      path : String,
      headers : Hash(String, String),
      body : IO?
    ) : {Int32, Hash(String, String), IO}
      # Build HTTP::Headers from hash
      http_headers = HTTP::Headers.new
      headers.each do |key, value|
        # Skip hop-by-hop headers
        next if key.downcase.in?("connection", "keep-alive", "transfer-encoding", "upgrade")
        http_headers[key] = value
      end

      # Make request to local service
      client = HTTP::Client.new(@host, @port)
      client.connect_timeout = 5.seconds
      client.read_timeout = 30.seconds

      response = case method.upcase
      when "GET"
        client.get(path, headers: http_headers)
      when "POST"
        client.post(path, headers: http_headers, body: body)
      when "PUT"
        client.put(path, headers: http_headers, body: body)
      when "PATCH"
        client.patch(path, headers: http_headers, body: body)
      when "DELETE"
        client.delete(path, headers: http_headers)
      when "HEAD"
        client.head(path, headers: http_headers)
      when "OPTIONS"
        client.options(path, headers: http_headers)
      else
        client.exec(method.upcase, path, headers: http_headers, body: body)
      end

      # Convert response headers to hash
      response_headers = {} of String => String
      response.headers.each do |key, values|
        response_headers[key] = values.first
      end

      {response.status_code, response_headers, response.body_io}
    rescue ex : Socket::ConnectError
      error_body = IO::Memory.new("Local service unavailable at #{@host}:#{@port}")
      {502, {"Content-Type" => "text/plain"}, error_body.as(IO)}
    rescue ex
      error_body = IO::Memory.new("Proxy error: #{ex.message}")
      {500, {"Content-Type" => "text/plain"}, error_body.as(IO)}
    end
  end
end
```

**Step 2: Implement TunnelClient**

Create `src/cli/tunnel_client.cr`:
```crystal
require "http/web_socket"
require "uri"
require "../core/protocol"
require "./local_proxy"
require "./config"

module Sellia::CLI
  class TunnelClient
    property server_url : String
    property api_key : String?
    property local_port : Int32
    property local_host : String
    property subdomain : String?
    property auth : String?

    property public_url : String?
    property tunnel_id : String?

    @socket : HTTP::WebSocket?
    @proxy : LocalProxy
    @running : Bool = false
    @request_bodies : Hash(String, IO::Memory) = {} of String => IO::Memory

    # Callbacks
    @on_connect : (String ->)?
    @on_request : (Protocol::Messages::RequestStart ->)?
    @on_disconnect : (->)?

    def initialize(
      @server_url : String,
      @local_port : Int32,
      @api_key : String? = nil,
      @local_host : String = "localhost",
      @subdomain : String? = nil,
      @auth : String? = nil
    )
      @proxy = LocalProxy.new(@local_host, @local_port)
    end

    def on_connect(&block : String ->)
      @on_connect = block
    end

    def on_request(&block : Protocol::Messages::RequestStart ->)
      @on_request = block
    end

    def on_disconnect(&block : ->)
      @on_disconnect = block
    end

    def start
      @running = true
      connect
    end

    def stop
      @running = false
      @socket.try(&.close)
    end

    private def connect
      uri = URI.parse(@server_url)
      ws_scheme = uri.scheme == "https" ? "wss" : "ws"
      ws_url = "#{ws_scheme}://#{uri.host}:#{uri.port || (uri.scheme == "https" ? 443 : 80)}/ws"

      puts "Connecting to #{ws_url}..."

      socket = HTTP::WebSocket.new(URI.parse(ws_url))
      @socket = socket

      socket.on_binary do |bytes|
        handle_message(bytes)
      end

      socket.on_close do
        puts "Disconnected from server"
        @on_disconnect.try(&.call)

        # Reconnect if still running
        if @running
          puts "Reconnecting in 3 seconds..."
          sleep 3.seconds
          connect if @running
        end
      end

      # Start the connection in a fiber
      spawn do
        socket.run
      end

      # Give socket time to connect
      sleep 0.1.seconds

      # Authenticate
      authenticate
    end

    private def authenticate
      socket = @socket
      return unless socket

      if key = @api_key
        send_message(Protocol::Messages::Auth.new(api_key: key))
      else
        # No auth required - just open tunnel
        open_tunnel
      end
    end

    private def open_tunnel
      send_message(Protocol::Messages::TunnelOpen.new(
        tunnel_type: "http",
        local_port: @local_port,
        subdomain: @subdomain,
        auth: @auth
      ))
    end

    private def handle_message(bytes : Bytes)
      message = Protocol::Message.from_msgpack(bytes)

      case message
      when Protocol::Messages::AuthOk
        puts "Authenticated successfully"
        open_tunnel

      when Protocol::Messages::AuthError
        puts "Authentication failed: #{message.error}"
        stop

      when Protocol::Messages::TunnelReady
        @tunnel_id = message.tunnel_id
        @public_url = message.url
        puts "Tunnel ready: #{message.url}"
        @on_connect.try(&.call(message.url))

      when Protocol::Messages::TunnelClose
        puts "Tunnel closed: #{message.reason}"
        stop

      when Protocol::Messages::RequestStart
        handle_request_start(message)

      when Protocol::Messages::RequestBody
        handle_request_body(message)

      when Protocol::Messages::Ping
        send_message(Protocol::Messages::Pong.new(message.timestamp))
      end
    rescue ex
      puts "Error handling message: #{ex.message}"
    end

    private def handle_request_start(message : Protocol::Messages::RequestStart)
      @on_request.try(&.call(message))

      # Initialize body buffer for this request
      @request_bodies[message.request_id] = IO::Memory.new
    end

    private def handle_request_body(message : Protocol::Messages::RequestBody)
      body_io = @request_bodies[message.request_id]?
      return unless body_io

      body_io.write(message.chunk) unless message.chunk.empty?

      if message.final
        # Request body complete - forward to local service
        body_io.rewind

        # Get the request start message headers from... we need to store it
        # Actually we need to refactor to store the full request
        # For now, spawn the proxy call
        spawn do
          forward_request(message.request_id)
        end
      end
    end

    # Store request metadata along with body
    @pending_requests : Hash(String, Protocol::Messages::RequestStart) = {} of String => Protocol::Messages::RequestStart

    private def handle_request_start(message : Protocol::Messages::RequestStart)
      @on_request.try(&.call(message))
      @pending_requests[message.request_id] = message
      @request_bodies[message.request_id] = IO::Memory.new
    end

    private def forward_request(request_id : String)
      start_msg = @pending_requests.delete(request_id)
      body_io = @request_bodies.delete(request_id)

      return unless start_msg && body_io

      body_io.rewind
      body = body_io.size > 0 ? body_io : nil

      status_code, headers, response_body = @proxy.forward(
        start_msg.method,
        start_msg.path,
        start_msg.headers,
        body
      )

      # Send response back
      send_message(Protocol::Messages::ResponseStart.new(
        request_id: request_id,
        status_code: status_code,
        headers: headers
      ))

      # Stream response body
      buffer = Bytes.new(8192)
      while (read = response_body.read(buffer)) > 0
        send_message(Protocol::Messages::ResponseBody.new(
          request_id: request_id,
          chunk: buffer[0, read].dup
        ))
      end

      send_message(Protocol::Messages::ResponseEnd.new(request_id: request_id))
    end

    private def send_message(message : Protocol::Message)
      @socket.try(&.send(message.to_msgpack))
    end
  end
end
```

**Step 3: Commit**

```bash
git add -A
git commit -m "feat(cli): Add tunnel client with local proxy forwarding"
```

---

### Task 10: Wire Up CLI Main Entry Point

**Files:**
- Modify: `src/cli/main.cr`

**Step 1: Implement CLI with commands**

Replace `src/cli/main.cr`:
```crystal
require "option_parser"
require "./config"
require "./tunnel_client"
require "../core/version"

module Sellia::CLI
  def self.run
    command = ARGV.shift?

    case command
    when "http"
      run_http_tunnel
    when "start"
      run_start
    when "auth"
      run_auth
    when "version", "-v", "--version"
      puts "Sellia v#{Sellia::VERSION}"
    when "help", "-h", "--help", nil
      print_help
    else
      STDERR.puts "Unknown command: #{command}"
      STDERR.puts "Run 'sellia help' for usage"
      exit 1
    end
  end

  private def self.run_http_tunnel
    config = Config.load

    port = 3000
    subdomain : String? = nil
    auth : String? = nil
    local_host = "localhost"
    server = config.server
    api_key = config.api_key
    inspector_port = config.inspector.port
    open_inspector = config.inspector.open

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia http <port> [options]"

      parser.on("--subdomain NAME", "-s NAME", "Request specific subdomain") { |s| subdomain = s }
      parser.on("--auth USER:PASS", "Enable basic auth") { |a| auth = a }
      parser.on("--host HOST", "Local host (default: localhost)") { |h| local_host = h }
      parser.on("--server URL", "Tunnel server URL") { |s| server = s }
      parser.on("--api-key KEY", "API key for authentication") { |k| api_key = k }
      parser.on("--inspector-port PORT", "Inspector UI port (default: 4040)") { |p| inspector_port = p.to_i }
      parser.on("--open", "Open inspector in browser") { open_inspector = true }
      parser.on("-h", "--help", "Show this help") { puts parser; exit 0 }

      parser.unknown_args do |args|
        if args.size > 0
          port = args[0].to_i rescue port
        end
      end
    end

    puts "Sellia v#{Sellia::VERSION}"
    puts "Forwarding to #{local_host}:#{port}"
    puts ""

    client = TunnelClient.new(
      server_url: server,
      local_port: port,
      api_key: api_key,
      local_host: local_host,
      subdomain: subdomain,
      auth: auth
    )

    client.on_connect do |url|
      puts ""
      puts "Public URL: #{url}"
      puts ""
      puts "Press Ctrl+C to stop"
    end

    client.on_request do |req|
      puts "#{req.method} #{req.path}"
    end

    # Handle shutdown
    Signal::INT.trap do
      puts "\nShutting down..."
      client.stop
      exit 0
    end

    Signal::TERM.trap do
      client.stop
      exit 0
    end

    client.start

    # Keep main fiber alive
    loop do
      sleep 1.second
    end
  end

  private def self.run_start
    config = Config.load

    config_file : String? = nil

    OptionParser.parse do |parser|
      parser.banner = "Usage: sellia start [options]"

      parser.on("--config FILE", "-c FILE", "Config file path") { |f| config_file = f }
      parser.on("-h", "--help", "Show this help") { puts parser; exit 0 }
    end

    # Load additional config file if specified
    if file = config_file
      if File.exists?(file)
        file_config = Config.from_yaml(File.read(file))
        config = config.merge(file_config)
      else
        STDERR.puts "Config file not found: #{file}"
        exit 1
      end
    end

    if config.tunnels.empty?
      STDERR.puts "No tunnels defined in config"
      STDERR.puts "Create a sellia.yml with tunnel definitions"
      exit 1
    end

    puts "Sellia v#{Sellia::VERSION}"
    puts "Starting #{config.tunnels.size} tunnel(s)..."
    puts ""

    clients = [] of TunnelClient

    config.tunnels.each do |name, tunnel_config|
      client = TunnelClient.new(
        server_url: config.server,
        local_port: tunnel_config.port,
        api_key: config.api_key,
        local_host: tunnel_config.local_host,
        subdomain: tunnel_config.subdomain,
        auth: tunnel_config.auth
      )

      client.on_connect do |url|
        puts "[#{name}] #{url} -> #{tunnel_config.local_host}:#{tunnel_config.port}"
      end

      clients << client
      spawn { client.start }
    end

    Signal::INT.trap do
      puts "\nShutting down..."
      clients.each(&.stop)
      exit 0
    end

    loop { sleep 1.second }
  end

  private def self.run_auth
    subcommand = ARGV.shift?

    case subcommand
    when "login"
      print "API Key: "
      api_key = gets.try(&.strip)

      if api_key && !api_key.empty?
        config_dir = Path.home / ".config" / "sellia"
        Dir.mkdir_p(config_dir) unless Dir.exists?(config_dir)

        config_path = config_dir / "sellia.yml"
        File.write(config_path, "api_key: #{api_key}\n")
        puts "API key saved to #{config_path}"
      else
        STDERR.puts "No API key provided"
        exit 1
      end

    when "logout"
      config_path = Path.home / ".config" / "sellia" / "sellia.yml"
      if File.exists?(config_path)
        File.delete(config_path)
        puts "Logged out"
      else
        puts "Not logged in"
      end

    when "status"
      config = Config.load
      if config.api_key
        puts "Logged in"
        puts "Server: #{config.server}"
      else
        puts "Not logged in"
      end

    else
      puts "Usage: sellia auth [login|logout|status]"
    end
  end

  private def self.print_help
    puts <<-HELP
    Sellia v#{Sellia::VERSION} - Secure tunnels to localhost

    Usage:
      sellia <command> [options]

    Commands:
      http <port>     Create HTTP tunnel to local port
      start           Start tunnels from config file
      auth            Manage authentication
      version         Show version
      help            Show this help

    Examples:
      sellia http 3000                    Tunnel to localhost:3000
      sellia http 3000 -s myapp           With custom subdomain
      sellia http 3000 --auth user:pass   With basic auth
      sellia start                        Start from sellia.yml

    Configuration:
      Config files are loaded in order (later overrides earlier):
        ~/.config/sellia/sellia.yml
        ~/.sellia.yml
        ./sellia.yml

    Environment:
      SELLIA_SERVER     Server URL
      SELLIA_API_KEY    API key
    HELP
  end
end

Sellia::CLI.run
```

**Step 2: Test CLI**

Run: `shards build && bin/sellia --help`
Expected: Help output

Run: `bin/sellia http --help`
Expected: HTTP tunnel help

**Step 3: Commit**

```bash
git add -A
git commit -m "feat(cli): Wire up CLI with http, start, and auth commands"
```

---

## Phase 4: Integration Testing

### Task 11: End-to-End Integration Test

**Files:**
- Create: `spec/integration/tunnel_spec.cr`

**Step 1: Write integration test**

Create `spec/integration/tunnel_spec.cr`:
```crystal
require "../spec_helper"
require "http/server"
require "../../src/server/server"
require "../../src/cli/tunnel_client"

describe "End-to-end tunnel" do
  it "proxies HTTP requests through tunnel" do
    # Start a simple local HTTP server
    local_server = HTTP::Server.new do |ctx|
      ctx.response.content_type = "text/plain"
      ctx.response.print("Hello from local!")
    end

    spawn { local_server.bind_tcp("127.0.0.1", 9999); local_server.listen }
    sleep 0.1.seconds

    # Start tunnel server
    server = Sellia::Server::Server.new(
      host: "127.0.0.1",
      port: 9998,
      domain: "127.0.0.1:9998"
    )
    spawn { server.start }
    sleep 0.2.seconds

    # Connect tunnel client
    client = Sellia::CLI::TunnelClient.new(
      server_url: "http://127.0.0.1:9998",
      local_port: 9999,
      subdomain: "test"
    )

    public_url : String? = nil
    client.on_connect { |url| public_url = url }

    spawn { client.start }
    sleep 0.5.seconds

    # Make request through tunnel
    public_url.should_not be_nil

    # Note: This test is simplified - full test would hit the subdomain
    # For local testing without DNS, you'd need to pass Host header

    client.stop
    local_server.close
  end
end
```

**Step 2: Run integration test**

Run: `crystal spec spec/integration/tunnel_spec.cr`
Expected: PASS (or document any issues)

**Step 3: Commit**

```bash
git add -A
git commit -m "test: Add end-to-end integration test"
```

---

## Phase 5: Web Inspector (Simplified MVP)

### Task 12: Set Up React Inspector Project

**Files:**
- Create: `web/package.json`
- Create: `web/vite.config.ts`
- Create: `web/tsconfig.json`
- Create: `web/index.html`
- Create: `web/src/main.tsx`
- Create: `web/src/App.tsx`

**Step 1: Initialize web project**

```bash
cd web
npm create vite@latest . -- --template react-ts
npm install
npm install -D tailwindcss @tailwindcss/vite
```

**Step 2: Configure Vite with Tailwind v4**

Update `web/vite.config.ts`:
```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  server: {
    port: 5173,
  },
})
```

**Step 3: Add Tailwind to CSS**

Update `web/src/index.css`:
```css
@import "tailwindcss";
```

**Step 4: Create basic App component**

Update `web/src/App.tsx`:
```tsx
import { useState, useEffect } from 'react'

interface Request {
  id: string
  method: string
  path: string
  statusCode: number
  duration: number
  timestamp: Date
  requestHeaders: Record<string, string>
  requestBody?: string
  responseHeaders: Record<string, string>
  responseBody?: string
}

function App() {
  const [requests, setRequests] = useState<Request[]>([])
  const [selected, setSelected] = useState<Request | null>(null)
  const [connected, setConnected] = useState(false)

  useEffect(() => {
    // Connect to inspector WebSocket
    const ws = new WebSocket(`ws://${window.location.host}/api/live`)

    ws.onopen = () => setConnected(true)
    ws.onclose = () => setConnected(false)

    ws.onmessage = (event) => {
      const data = JSON.parse(event.data)
      if (data.type === 'request') {
        setRequests(prev => [data.request, ...prev].slice(0, 1000))
      }
    }

    return () => ws.close()
  }, [])

  const statusColor = (code: number) => {
    if (code < 300) return 'text-green-500'
    if (code < 400) return 'text-blue-500'
    if (code < 500) return 'text-yellow-500'
    return 'text-red-500'
  }

  const copyAsCurl = (req: Request) => {
    const headers = Object.entries(req.requestHeaders)
      .map(([k, v]) => `-H '${k}: ${v}'`)
      .join(' ')
    const curl = `curl -X ${req.method} ${headers} '${window.location.origin}${req.path}'`
    navigator.clipboard.writeText(curl)
  }

  return (
    <div className="min-h-screen bg-gray-900 text-gray-100">
      {/* Header */}
      <header className="border-b border-gray-700 px-4 py-3 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <h1 className="text-lg font-semibold">Sellia Inspector</h1>
          <span className={`text-xs px-2 py-0.5 rounded ${connected ? 'bg-green-600' : 'bg-red-600'}`}>
            {connected ? 'Live' : 'Disconnected'}
          </span>
        </div>
        <button
          onClick={() => setRequests([])}
          className="text-sm text-gray-400 hover:text-white"
        >
          Clear All
        </button>
      </header>

      <div className="flex h-[calc(100vh-57px)]">
        {/* Request List */}
        <div className="w-1/2 border-r border-gray-700 overflow-y-auto">
          {requests.length === 0 ? (
            <div className="p-8 text-center text-gray-500">
              Waiting for requests...
            </div>
          ) : (
            requests.map(req => (
              <div
                key={req.id}
                onClick={() => setSelected(req)}
                className={`px-4 py-2 border-b border-gray-800 cursor-pointer hover:bg-gray-800 ${
                  selected?.id === req.id ? 'bg-gray-800' : ''
                }`}
              >
                <div className="flex items-center gap-3">
                  <span className={`font-mono ${statusColor(req.statusCode)}`}>
                    {req.statusCode}
                  </span>
                  <span className="font-mono text-sm text-gray-300">
                    {req.method}
                  </span>
                  <span className="font-mono text-sm truncate flex-1">
                    {req.path}
                  </span>
                  <span className="text-xs text-gray-500">
                    {req.duration}ms
                  </span>
                </div>
              </div>
            ))
          )}
        </div>

        {/* Request Detail */}
        <div className="w-1/2 overflow-y-auto p-4">
          {selected ? (
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <h2 className="text-lg font-semibold">
                  {selected.method} {selected.path}
                </h2>
                <button
                  onClick={() => copyAsCurl(selected)}
                  className="text-sm px-3 py-1 bg-gray-700 rounded hover:bg-gray-600"
                >
                  Copy as curl
                </button>
              </div>

              <section>
                <h3 className="text-sm font-semibold text-gray-400 mb-2">Request Headers</h3>
                <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto">
                  {JSON.stringify(selected.requestHeaders, null, 2)}
                </pre>
              </section>

              {selected.requestBody && (
                <section>
                  <h3 className="text-sm font-semibold text-gray-400 mb-2">Request Body</h3>
                  <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto">
                    {selected.requestBody}
                  </pre>
                </section>
              )}

              <section>
                <h3 className="text-sm font-semibold text-gray-400 mb-2">Response Headers</h3>
                <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto">
                  {JSON.stringify(selected.responseHeaders, null, 2)}
                </pre>
              </section>

              {selected.responseBody && (
                <section>
                  <h3 className="text-sm font-semibold text-gray-400 mb-2">Response Body</h3>
                  <pre className="bg-gray-800 p-3 rounded text-sm overflow-x-auto whitespace-pre-wrap">
                    {selected.responseBody}
                  </pre>
                </section>
              )}
            </div>
          ) : (
            <div className="h-full flex items-center justify-center text-gray-500">
              Select a request to view details
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export default App
```

**Step 5: Build and verify**

```bash
cd web && npm run build
```

Expected: `web/dist/` created with built assets

**Step 6: Commit**

```bash
git add -A
git commit -m "feat(web): Add React inspector UI with Tailwind v4"
```

---

### Task 13: Integrate Inspector into CLI

**Files:**
- Create: `src/cli/inspector.cr`
- Create: `src/cli/request_store.cr`
- Modify: `src/cli/tunnel_client.cr`
- Create: `justfile`

**Step 1: Create RequestStore**

Create `src/cli/request_store.cr`:
```crystal
require "json"
require "mutex"

module Sellia::CLI
  struct StoredRequest
    include JSON::Serializable

    property id : String
    property method : String
    property path : String
    property status_code : Int32
    property duration : Int64  # milliseconds
    property timestamp : Time
    property request_headers : Hash(String, String)
    property request_body : String?
    property response_headers : Hash(String, String)
    property response_body : String?

    def initialize(
      @id : String,
      @method : String,
      @path : String,
      @status_code : Int32,
      @duration : Int64,
      @timestamp : Time,
      @request_headers : Hash(String, String),
      @request_body : String?,
      @response_headers : Hash(String, String),
      @response_body : String?
    )
    end
  end

  class RequestStore
    MAX_REQUESTS = 1000

    def initialize
      @requests = [] of StoredRequest
      @mutex = Mutex.new
      @subscribers = [] of Channel(StoredRequest)
    end

    def add(request : StoredRequest)
      @mutex.synchronize do
        @requests.unshift(request)
        @requests = @requests[0, MAX_REQUESTS] if @requests.size > MAX_REQUESTS

        @subscribers.each do |ch|
          ch.send(request) rescue nil
        end
      end
    end

    def all : Array(StoredRequest)
      @mutex.synchronize { @requests.dup }
    end

    def clear
      @mutex.synchronize { @requests.clear }
    end

    def subscribe : Channel(StoredRequest)
      ch = Channel(StoredRequest).new(100)
      @mutex.synchronize { @subscribers << ch }
      ch
    end

    def unsubscribe(ch : Channel(StoredRequest))
      @mutex.synchronize { @subscribers.delete(ch) }
    end
  end
end
```

**Step 2: Create Inspector server**

Create `src/cli/inspector.cr`:
```crystal
require "http/server"
require "http/web_socket"
require "json"
require "./request_store"

module Sellia::CLI
  class Inspector
    property port : Int32
    property store : RequestStore

    def initialize(@port : Int32, @store : RequestStore)
    end

    def start
      server = HTTP::Server.new do |context|
        handle_request(context)
      end

      address = server.bind_tcp("127.0.0.1", @port)
      puts "Inspector running at http://#{address}"

      server.listen
    end

    private def handle_request(context : HTTP::Server::Context)
      path = context.request.path

      case path
      when "/api/live"
        # WebSocket for live updates
        if context.request.headers["Upgrade"]?.try(&.downcase) == "websocket"
          ws_handler = HTTP::WebSocketHandler.new do |socket, ctx|
            handle_websocket(socket)
          end
          ws_handler.call(context)
        else
          context.response.status_code = 400
          context.response.print("WebSocket required")
        end

      when "/api/requests"
        context.response.content_type = "application/json"
        context.response.print(@store.all.to_json)

      when "/"
        serve_static(context, "index.html", "text/html")

      else
        # Serve static files
        file_path = path.lstrip('/')
        if file_path.ends_with?(".js")
          serve_static(context, file_path, "application/javascript")
        elsif file_path.ends_with?(".css")
          serve_static(context, file_path, "text/css")
        else
          context.response.status_code = 404
          context.response.print("Not found")
        end
      end
    end

    private def handle_websocket(socket : HTTP::WebSocket)
      channel = @store.subscribe

      spawn do
        loop do
          select
          when request = channel.receive
            message = {type: "request", request: request}.to_json
            socket.send(message) rescue break
          end
        end
      end

      socket.on_close do
        @store.unsubscribe(channel)
        channel.close
      end

      socket.run
    end

    private def serve_static(context : HTTP::Server::Context, file : String, content_type : String)
      {% if flag?(:embed_assets) %}
        # Embedded assets for release builds
        content = {{ read_file("#{__DIR__}/../../web/dist/" + file) }}
        context.response.content_type = content_type
        context.response.print(content)
      {% else %}
        # Development: proxy to Vite
        begin
          response = HTTP::Client.get("http://localhost:5173/#{file}")
          context.response.status_code = response.status_code
          context.response.content_type = content_type
          context.response.print(response.body)
        rescue
          context.response.status_code = 502
          context.response.print("Vite dev server not running. Start with: cd web && npm run dev")
        end
      {% end %}
    end
  end
end
```

**Step 3: Create justfile**

Create `justfile`:
```just
# Development
dev-web:
    cd web && npm run dev

dev-cli *args:
    shards run sellia -- {{args}}

dev-server *args:
    shards run sellia-server -- {{args}}

# Build
build-web:
    cd web && npm run build

build: build-web
    shards build --release -Dembed_assets

build-dev:
    shards build

# Testing
test:
    crystal spec

test-watch:
    watchexec -e cr crystal spec

# Install dependencies
install:
    shards install
    cd web && npm install

# Clean
clean:
    rm -rf bin/ web/dist/ lib/

# Format
fmt:
    crystal tool format
```

**Step 4: Commit**

```bash
git add -A
git commit -m "feat(cli): Add request inspector with embedded React UI"
```

---

### Task 14: Final Integration and Testing

**Step 1: Update CLI to start inspector**

Update `src/cli/main.cr` to include inspector startup (add to run_http_tunnel):

Add after client.start:
```crystal
# Start inspector
inspector = Inspector.new(inspector_port, request_store)
spawn { inspector.start }

if open_inspector
  # Open browser (macOS/Linux)
  Process.run("open", ["http://127.0.0.1:#{inspector_port}"]) rescue nil
end
```

**Step 2: Manual end-to-end test**

Terminal 1:
```bash
just dev-web
```

Terminal 2:
```bash
just dev-server
```

Terminal 3:
```bash
just dev-cli http 8080
```

Terminal 4:
```bash
python -m http.server 8080
```

Then open the public URL in browser - should see directory listing.
Open inspector at localhost:4040 - should see requests.

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: Complete Tier 1 MVP integration"
```

---

## Summary

This plan covers the complete Tier 1 MVP:

1. **Phase 1** - Project structure and MessagePack protocol
2. **Phase 2** - Server with WebSocket gateway and HTTP routing
3. **Phase 3** - CLI with config system and tunnel client
4. **Phase 4** - Integration testing
5. **Phase 5** - React inspector UI

Total: ~14 tasks, each with detailed TDD steps.

After completing this plan, you'll have a working tunnel server and CLI that can:
- Create HTTP tunnels with custom subdomains
- Proxy requests to local services
- Show live request inspector
- Support basic auth protection
- Load layered configuration

Tier 2 features (TCP tunnels, request replay, custom domains) can be added incrementally.
