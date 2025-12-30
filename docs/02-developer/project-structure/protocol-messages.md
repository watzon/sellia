# Protocol Message Types Reference

Complete reference of all MessagePack protocol message types used in Sellia.

## Base Message Class

All protocol messages extend `Sellia::Protocol::Message`:

```crystal
abstract class Message
  include MessagePack::Serializable

  # Type discriminator for polymorphic deserialization
  use_msgpack_discriminator "type", {
    auth:             Messages::Auth,
    auth_ok:          Messages::AuthOk,
    auth_error:       Messages::AuthError,
    tunnel_open:      Messages::TunnelOpen,
    tunnel_ready:     Messages::TunnelReady,
    tunnel_close:     Messages::TunnelClose,
    request_start:    Messages::RequestStart,
    request_body:     Messages::RequestBody,
    response_start:   Messages::ResponseStart,
    response_body:    Messages::ResponseBody,
    response_end:     Messages::ResponseEnd,
    ping:             Messages::Ping,
    pong:             Messages::Pong,
    ws_upgrade:       Messages::WebSocketUpgrade,
    ws_upgrade_ok:    Messages::WebSocketUpgradeOk,
    ws_upgrade_error: Messages::WebSocketUpgradeError,
    ws_frame:         Messages::WebSocketFrame,
    ws_close:         Messages::WebSocketClose,
  }

  abstract def type : String
end
```

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/message.cr`

## Message Types by Category

### Authentication Messages

#### Auth (Client → Server)

Authentication request with API key.

```crystal
class Auth < Message
  property type : String = "auth"
  property api_key : String

  def initialize(@api_key : String)
  end
end
```

**Fields**:
- `type`: Always `"auth"`
- `api_key`: API key for authentication

**When Sent**:
- Immediately after WebSocket connection
- Only if server requires authentication

**Response**:
- `AuthOk` on success
- `AuthError` on failure

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/auth.cr`

---

#### AuthOk (Server → Client)

Authentication successful response.

```crystal
class AuthOk < Message
  property type : String = "auth_ok"
  property account_id : String
  property limits : Hash(String, Int64)

  def initialize(@account_id : String, @limits : Hash(String, Int64) = {} of String => Int64)
  end
end
```

**Fields**:
- `type`: Always `"auth_ok"`
- `account_id`: Unique account identifier
- `limits`: Rate limit configuration (empty hash by default)
  - `max_tunnels`: Maximum tunnels allowed
  - `max_connections`: Maximum concurrent connections

**When Sent**:
- After successful `Auth` validation

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/auth.cr`

---

#### AuthError (Server → Client)

Authentication failed response.

```crystal
class AuthError < Message
  property type : String = "auth_error"
  property error : String

  def initialize(@error : String)
  end
end
```

**Fields**:
- `type`: Always `"auth_error"`
- `error`: Human-readable error message

**When Sent**:
- When API key is invalid or missing
- When account is suspended

**Client Behavior**:
- Disable auto-reconnect
- Close connection
- Display error to user

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/auth.cr`

---

### Tunnel Management Messages

#### TunnelOpen (Client → Server)

Request to create a new tunnel.

```crystal
class TunnelOpen < Message
  property type : String = "tunnel_open"
  property tunnel_type : String # "http" or "tcp"
  property local_port : Int32
  property subdomain : String? # Optional: custom subdomain
  property auth : String?      # Optional: "user:pass" for basic auth

  def initialize(
    @tunnel_type : String,
    @local_port : Int32,
    @subdomain : String? = nil,
    @auth : String? = nil,
  )
  end
end
```

**Fields**:
- `type`: Always `"tunnel_open"`
- `tunnel_type`: Tunnel type (`"http"` currently, `"tcp"` reserved for future)
- `local_port`: Local service port
- `subdomain`: Optional custom subdomain (3-63 chars)
- `auth`: Optional basic auth credential (`"user:pass"`)

**When Sent**:
- After successful authentication
- Or immediately if auth disabled

**Response**:
- `TunnelReady` on success
- `TunnelClose` on failure

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/tunnel.cr`

**Subdomain Rules**:
- 3-63 characters
- Alphanumeric and hyphens only
- Cannot start/end with hyphen
- No consecutive hyphens
- Must not be reserved
- Must be available

---

#### TunnelReady (Server → Client)

Tunnel created successfully and ready to receive requests.

```crystal
class TunnelReady < Message
  property type : String = "tunnel_ready"
  property tunnel_id : String
  property url : String
  property subdomain : String

  def initialize(@tunnel_id : String, @url : String, @subdomain : String)
  end
end
```

**Fields**:
- `type`: Always `"tunnel_ready"`
- `tunnel_id`: Unique tunnel identifier (32 hex chars)
- `url`: Full public URL
- `subdomain`: Assigned subdomain

**When Sent**:
- After tunnel is registered
- Subdomain is validated and assigned

**URL Format**:
- HTTP: `http://subdomain.domain:port`
- HTTPS: `https://subdomain.domain`

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/tunnel.cr`

---

#### TunnelClose (Bidirectional)

Tunnel is being closed.

```crystal
class TunnelClose < Message
  property type : String = "tunnel_close"
  property tunnel_id : String
  property reason : String?

  def initialize(@tunnel_id : String, @reason : String? = nil)
  end
end
```

**Fields**:
- `type`: Always `"tunnel_close"`
- `tunnel_id`: Tunnel being closed
- `reason`: Optional reason for closure

**When Sent**:
- **Server → Client**: Tunnel closed due to error, subdomain conflict, or server shutdown
- **Client → Server**: Client explicitly closing tunnel

**Common Reasons**:
- `"Subdomain 'xxx' is not available"`
- `"Rate limit exceeded: too many tunnel creations"`
- `"Connection timeout"`
- `"Not authenticated"`

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/tunnel.cr`

---

### HTTP Request Messages

#### RequestStart (Server → Client)

Start of an incoming HTTP request.

```crystal
class RequestStart < Message
  property type : String = "request_start"
  property request_id : String
  property tunnel_id : String
  property method : String
  property path : String
  property headers : Hash(String, Array(String))

  def initialize(
    @request_id : String,
    @tunnel_id : String,
    @method : String,
    @path : String,
    @headers : Hash(String, Array(String)),
  )
  end
end
```

**Fields**:
- `type`: Always `"request_start"`
- `request_id`: Unique request identifier (32 hex chars)
- `tunnel_id`: Tunnel this request is for
- `method`: HTTP method (`GET`, `POST`, etc.)
- `path`: Full path including query string
- `headers`: Multi-value header hash

**When Sent**:
- When server receives HTTP request for tunnel
- Before request body chunks

**Client Behavior**:
- Store request metadata
- Initialize body buffer
- Wait for body chunks

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/request.cr`

---

#### RequestBody (Server → Client)

Request body chunk (streaming).

```crystal
class RequestBody < Message
  property type : String = "request_body"
  property request_id : String
  property chunk : Bytes
  property final : Bool

  def initialize(@request_id : String, @chunk : Bytes, @final : Bool = false)
  end
end
```

**Fields**:
- `type`: Always `"request_body"`
- `request_id`: Request identifier
- `chunk`: Binary data chunk (up to 8KB)
- `final`: `true` on last chunk (defaults to `false`)

**When Sent**:
- One or more times after `RequestStart`
- `final=true` on last chunk (even if empty)

**Client Behavior**:
- Append chunk to body buffer
- When `final=true`, forward request to local service

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/request.cr`

---

### HTTP Response Messages

#### ResponseStart (Client → Server)

Start of HTTP response from local service.

```crystal
class ResponseStart < Message
  property type : String = "response_start"
  property request_id : String
  property status_code : Int32
  property headers : Hash(String, Array(String))

  def initialize(
    @request_id : String,
    @status_code : Int32,
    @headers : Hash(String, Array(String)),
  )
  end
end
```

**Fields**:
- `type`: Always `"response_start"`
- `request_id`: Request being responded to
- `status_code`: HTTP status code (200, 404, etc.)
- `headers`: Response headers

**When Sent**:
- After receiving response from local service
- Before response body chunks

**Server Behavior**:
- Write status code to HTTP response
- Write headers to HTTP response

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/request.cr`

---

#### ResponseBody (Client → Server)

Response body chunk (streaming).

```crystal
class ResponseBody < Message
  property type : String = "response_body"
  property request_id : String
  property chunk : Bytes

  def initialize(@request_id : String, @chunk : Bytes)
  end
end
```

**Fields**:
- `type`: Always `"response_body"`
- `request_id`: Request being responded to
- `chunk`: Binary data chunk (up to 8KB)

**When Sent**:
- One or more times after `ResponseStart`
- Stream response body in chunks

**Server Behavior**:
- Write chunk to HTTP response body
- Flush to send to client

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/request.cr`

---

#### ResponseEnd (Client → Server)

End of HTTP response.

```crystal
class ResponseEnd < Message
  property type : String = "response_end"
  property request_id : String

  def initialize(@request_id : String)
  end
end
```

**Fields**:
- `type`: Always `"response_end"`
- `request_id`: Request being responded to

**When Sent**:
- After all response body chunks sent

**Server Behavior**:
- Complete HTTP response
- Remove from pending request store
- Signal waiting fiber

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/request.cr`

---

### Keep-Alive Messages

#### Ping (Server → Client)

Keep-alive ping.

```crystal
class Ping < Message
  property type : String = "ping"
  property timestamp : Int64

  def initialize(@timestamp : Int64 = Time.utc.to_unix_ms)
  end
end
```

**Fields**:
- `type`: Always `"ping"`
- `timestamp`: Unix timestamp in milliseconds (defaults to current time)

**When Sent**:
- Every 30 seconds
- To detect stale connections

**Client Behavior**:
- Immediately respond with `Pong`
- Update last activity timestamp

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/request.cr`

---

#### Pong (Client → Server)

Keep-alive pong response.

```crystal
class Pong < Message
  property type : String = "pong"
  property timestamp : Int64

  def initialize(@timestamp : Int64 = Time.utc.to_unix_ms)
  end
end
```

**Fields**:
- `type`: Always `"pong"`
- `timestamp`: Timestamp from ping (echoed back, defaults to current time)

**When Sent**:
- In response to `Ping`

**Server Behavior**:
- Update client's last activity timestamp
- Don't timeout connection

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/request.cr`

---

### WebSocket Messages

#### WebSocketUpgrade (Server → Client)

Incoming WebSocket upgrade request.

```crystal
class WebSocketUpgrade < Message
  property type : String = "ws_upgrade"
  property request_id : String
  property tunnel_id : String
  property path : String
  property headers : Hash(String, Array(String))

  def initialize(
    @request_id : String,
    @tunnel_id : String,
    @path : String,
    @headers : Hash(String, Array(String)),
  )
  end
end
```

**Fields**:
- `type`: Always `"ws_upgrade"`
- `request_id`: Unique identifier for this WebSocket
- `tunnel_id`: Tunnel for this WebSocket
- `path`: WebSocket path
- `headers`: All headers including `Sec-WebSocket-*`

**Important Headers**:
- `Sec-WebSocket-Key`: Handshake key
- `Sec-WebSocket-Version`: Must be "13"
- `Sec-WebSocket-Protocol`: Optional subprotocol

**When Sent**:
- When server receives WebSocket upgrade request

**Client Behavior**:
- Route to local WebSocket service
- Attempt connection
- Respond with `WebSocketUpgradeOk` or `WebSocketUpgradeError`

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/websocket.cr`

---

#### WebSocketUpgradeOk (Client → Server)

Local service accepted WebSocket connection.

```crystal
class WebSocketUpgradeOk < Message
  property type : String = "ws_upgrade_ok"
  property request_id : String
  property headers : Hash(String, Array(String))

  def initialize(
    @request_id : String,
    @headers : Hash(String, Array(String)) = {} of String => Array(String),
  )
  end
end
```

**Fields**:
- `type`: Always `"ws_upgrade_ok"`
- `request_id`: WebSocket identifier
- `headers`: Optional response headers (e.g., `Sec-WebSocket-Protocol`, defaults to empty hash)

**When Sent**:
- After successfully connecting to local WebSocket service

**Server Behavior**:
- Complete handshake with external client
- Start frame forwarding loop

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/websocket.cr`

---

#### WebSocketUpgradeError (Client → Server)

Local service rejected WebSocket connection.

```crystal
class WebSocketUpgradeError < Message
  property type : String = "ws_upgrade_error"
  property request_id : String
  property status_code : Int32
  property message : String

  def initialize(
    @request_id : String,
    @status_code : Int32,
    @message : String,
  )
  end
end
```

**Fields**:
- `type`: Always `"ws_upgrade_error"`
- `request_id`: WebSocket identifier
- `status_code`: HTTP status code (usually 502)
- `message`: Error description

**When Sent**:
- If local service unavailable
- If connection fails
- If local service rejects upgrade

**Server Behavior**:
- Send error response to external client
- Close connection

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/websocket.cr`

---

#### WebSocketFrame (Bidirectional)

WebSocket frame data.

```crystal
class WebSocketFrame < Message
  property type : String = "ws_frame"
  property request_id : String
  property opcode : UInt8
  property payload : Bytes
  property fin : Bool

  def initialize(
    @request_id : String,
    @opcode : UInt8,
    @payload : Bytes,
    @fin : Bool = true,
  )
  end
end
```

**Fields**:
- `type`: Always `"ws_frame"`
- `request_id`: WebSocket identifier
- `opcode`: Frame opcode (see below)
- `payload`: Frame payload data
- `fin`: Whether this is the final frame (defaults to `true`)

**Opcode Values**:
- `0x01` - Text frame
- `0x02` - Binary frame
- `0x08` - Close
- `0x09` - Ping
- `0x0A` - Pong

**When Sent**:
- Bidirectional after WebSocket upgrade
- For each WebSocket frame

**Fragmentation**:
- Text/Binary frames can be fragmented
- `fin=false` on fragments, `fin=true` on final
- Continuation frames use same opcode as initial frame

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/websocket.cr`

---

#### WebSocketClose (Bidirectional)

WebSocket connection closing.

```crystal
class WebSocketClose < Message
  property type : String = "ws_close"
  property request_id : String
  property code : UInt16?
  property reason : String?

  def initialize(
    @request_id : String,
    @code : UInt16? = nil,
    @reason : String? = nil,
  )
  end
end
```

**Fields**:
- `type`: Always `"ws_close"`
- `request_id`: WebSocket identifier
- `code`: Optional WebSocket close code (defaults to `nil`)
- `reason`: Optional close reason (defaults to `nil`)

**Common Close Codes**:
- `1000` - Normal closure
- `1001` - Going away
- `1002` - Protocol error
- `1003` - Unsupported data
- `1006` - Abnormal closure
- `1008` - Policy violation
- `1009` - Message too big
- `1011` - Internal error

**When Sent**:
- When either side closes WebSocket
- To gracefully shutdown connection

**Behavior**:
- Remove from pending WebSocket store
- Close connection to other side
- Clean up resources

**Location**: `/Users/watzon/conductor/workspaces/sellia/winnipeg/src/core/protocol/messages/websocket.cr`

---

## Message Serialization

### To MessagePack

```crystal
message = Protocol::Messages::Auth.new("key_...")
bytes = message.to_msgpack
# => Bytes containing MessagePack binary data
```

### From MessagePack

```crystal
message = Protocol::Message.from_msgpack(bytes)

case message
when Protocol::Messages::Auth
  puts "Auth: #{message.api_key}"
when Protocol::Messages::TunnelReady
  puts "Tunnel ready: #{message.url}"
end
```

The `type` field is used for polymorphic deserialization.

---

## Request ID Generation

Request IDs are generated using cryptographically secure random:

```crystal
request_id = Random::Secure.hex(16)  # 32 hex characters
```

Example: `"a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"`

These IDs:
- Are unique per request
- Cannot be guessed
- Used to correlate request/response messages

---

## Header Format

Headers use multi-value hash to preserve multiple values:

```crystal
headers = Hash(String, Array(String)).new
headers["Set-Cookie"] = ["session=abc", "theme=dark"]
headers["Accept"] = ["application/json", "text/html"]
```

When serializing to MessagePack:
```json
{
  "Set-Cookie": ["session=abc", "theme=dark"],
  "Accept": ["application/json", "text/html"]
}
```

---

## Binary Data Handling

### Request/Response Bodies

Sent as raw bytes in MessagePack binary format:

```crystal
class RequestBody < Message
  property chunk : Bytes  # Serialized as bin8/bin16/bin32
end
```

Chunk sizes:
- Recommended: 8KB (8192 bytes)
- Maximum: Limited by memory

### WebSocket Payloads

Same as request/response bodies - sent as raw bytes.

---

## Message Flow Examples

### Simple HTTP Request

```
Server → Client: RequestStart(id="req1", method="GET", path="/api")
Server → Client: RequestBody(id="req1", chunk=Bytes.empty, final=true)
Client → Server: ResponseStart(id="req1", status=200, headers={...})
Client → Server: ResponseBody(id="req1", chunk="Hello World".to_slice)
Client → Server: ResponseEnd(id="req1")
```

### HTTP Request with Body

```
Server → Client: RequestStart(id="req2", method="POST", path="/api/users")
Server → Client: RequestBody(id="req2", chunk='{"name":', final=false)
Server → Client: RequestBody(id="req2", chunk=' "Alice"}', final=true)
Client → Server: ResponseStart(id="req2", status=201, headers={...})
Client → Server: ResponseBody(id="req2", chunk='{"id": 1}'.to_slice)
Client → Server: ResponseEnd(id="req2")
```

### WebSocket Connection

```
Server → Client: WebSocketUpgrade(id="ws1", path="/socket", headers={...})
Client → Server: WebSocketUpgradeOk(id="ws1", headers={...})
Client → Server: WebSocketFrame(id="ws1", opcode=0x01, payload="Hello")
Server → Client: WebSocketFrame(id="ws1", opcode=0x01, payload="Hi there")
Server → Client: WebSocketClose(id="ws1", code=1000, reason="Normal")
Client → Server: WebSocketClose(id="ws1", code=1000, reason="Normal")
```

---

## Error Handling

### Invalid Message Type

If unknown `type` received:
```
Error: MessagePack::Error
Message: Unknown discriminator value: "unknown_type"
```

### Missing Required Fields

MessagePack deserialization will raise:
```
Error: MessagePack::Error
Message: Missing required field: "request_id"
```

### Malformed Binary Data

Binary fields expect `Bytes` type - receiving other types raises error during deserialization.

---

## Performance Considerations

### Message Size

- Authentication messages: ~100 bytes
- RequestStart: ~500 bytes (depends on headers)
- RequestBody: ~8KB per chunk
- ResponseStart: ~300 bytes
- ResponseBody: ~8KB per chunk

### Serialization Overhead

MessagePack serialization adds:
- Type discriminator (string): ~10 bytes
- Field names: ~5-20 bytes per field
- Binary metadata: ~5 bytes

### Compression

Currently not compressed. Future versions may add:
- Per-message compression (WebSocket permessage-deflate)
- Header compression (dynamic dictionaries)

---

## Version Compatibility

### Protocol Versioning

The `type` field allows protocol evolution:
- New message types can be added
- Old clients ignore unknown types
- Servers must handle both old and new formats

### Backward Compatibility

When adding new fields:
1. Make fields optional (use `?` or provide default)
2. Old clients will deserialize without new fields
3. Servers must handle missing fields

Example:
```crystal
class TunnelReady < Message
  property url : String
  property region : String?  # New optional field
end
```

### Forward Compatibility

When removing fields:
1. Keep field in protocol but mark deprecated
2. Servers must accept field but ignore it
3. Remove in next major version
