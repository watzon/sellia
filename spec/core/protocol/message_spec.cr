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

    it "deserializes an auth_ok message" do
      msg = Sellia::Protocol::Messages::AuthOk.new(
        account_id: "acc_123",
        limits: {"max_tunnels" => 10_i64, "max_connections" => 100_i64}
      )
      packed = msg.to_msgpack

      unpacked = Sellia::Protocol::Message.from_msgpack(packed)
      unpacked.should be_a(Sellia::Protocol::Messages::AuthOk)
      auth_ok = unpacked.as(Sellia::Protocol::Messages::AuthOk)
      auth_ok.account_id.should eq("acc_123")
      auth_ok.limits["max_tunnels"].should eq(10)
    end

    it "deserializes an auth_error message" do
      msg = Sellia::Protocol::Messages::AuthError.new(error: "Invalid API key")
      packed = msg.to_msgpack

      unpacked = Sellia::Protocol::Message.from_msgpack(packed)
      unpacked.should be_a(Sellia::Protocol::Messages::AuthError)
      unpacked.as(Sellia::Protocol::Messages::AuthError).error.should eq("Invalid API key")
    end
  end
end

describe Sellia::Protocol::Messages::Auth do
  it "serializes to msgpack with type field" do
    msg = Sellia::Protocol::Messages::Auth.new(api_key: "sk_test_123")
    packed = msg.to_msgpack

    # Verify the packed bytes can be unpacked to a hash with type field
    unpacked = Hash(String, String).from_msgpack(packed)
    unpacked["type"].should eq("auth")
    unpacked["api_key"].should eq("sk_test_123")
  end
end

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

  it "handles nil optional fields" do
    original = Sellia::Protocol::Messages::TunnelOpen.new(
      tunnel_type: "http",
      local_port: 3000
    )

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::TunnelOpen)
    msg.subdomain.should be_nil
    msg.auth.should be_nil
  end
end

describe Sellia::Protocol::Messages::TunnelReady do
  it "round-trips through msgpack" do
    original = Sellia::Protocol::Messages::TunnelReady.new(
      tunnel_id: "tun-123",
      url: "https://myapp.example.com",
      subdomain: "myapp"
    )

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::TunnelReady)
    msg.tunnel_id.should eq("tun-123")
    msg.url.should eq("https://myapp.example.com")
    msg.subdomain.should eq("myapp")
  end
end

describe Sellia::Protocol::Messages::TunnelClose do
  it "round-trips with optional reason" do
    original = Sellia::Protocol::Messages::TunnelClose.new(
      tunnel_id: "tun-123",
      reason: "Client disconnected"
    )

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::TunnelClose)
    msg.tunnel_id.should eq("tun-123")
    msg.reason.should eq("Client disconnected")
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
    msg.request_id.should eq("req-123")
    msg.tunnel_id.should eq("tun-456")
    msg.method.should eq("POST")
    msg.path.should eq("/api/users")
    msg.headers["Content-Type"].should eq("application/json")
    msg.headers["X-Custom"].should eq("value")
  end
end

describe Sellia::Protocol::Messages::RequestBody do
  it "round-trips binary data" do
    chunk = Bytes[0x01, 0x02, 0x03, 0x04]
    original = Sellia::Protocol::Messages::RequestBody.new(
      request_id: "req-123",
      chunk: chunk,
      final: true
    )

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::RequestBody)
    msg.request_id.should eq("req-123")
    msg.chunk.should eq(chunk)
    msg.final.should be_true
  end
end

describe Sellia::Protocol::Messages::ResponseStart do
  it "round-trips response metadata" do
    original = Sellia::Protocol::Messages::ResponseStart.new(
      request_id: "req-123",
      status_code: 200,
      headers: {"Content-Type" => "application/json"}
    )

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::ResponseStart)
    msg.request_id.should eq("req-123")
    msg.status_code.should eq(200)
    msg.headers["Content-Type"].should eq("application/json")
  end
end

describe Sellia::Protocol::Messages::ResponseBody do
  it "round-trips response chunks" do
    chunk = "Hello World".to_slice
    original = Sellia::Protocol::Messages::ResponseBody.new(
      request_id: "req-123",
      chunk: chunk
    )

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::ResponseBody)
    msg.request_id.should eq("req-123")
    msg.chunk.should eq(chunk)
  end
end

describe Sellia::Protocol::Messages::ResponseEnd do
  it "round-trips request completion" do
    original = Sellia::Protocol::Messages::ResponseEnd.new(request_id: "req-123")

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::ResponseEnd)
    msg.request_id.should eq("req-123")
  end
end

describe Sellia::Protocol::Messages::Ping do
  it "includes timestamp" do
    original = Sellia::Protocol::Messages::Ping.new(timestamp: 1234567890_i64)

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::Ping)
    msg.timestamp.should eq(1234567890)
  end
end

describe Sellia::Protocol::Messages::Pong do
  it "echoes timestamp" do
    original = Sellia::Protocol::Messages::Pong.new(timestamp: 1234567890_i64)

    packed = original.to_msgpack
    unpacked = Sellia::Protocol::Message.from_msgpack(packed)

    msg = unpacked.as(Sellia::Protocol::Messages::Pong)
    msg.timestamp.should eq(1234567890)
  end
end
