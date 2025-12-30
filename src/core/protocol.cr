# Protocol message types for Sellia tunnel communication
#
# The protocol uses MessagePack for binary serialization with a "type" field
# as the discriminator for polymorphic deserialization.
#
# Message types:
# - Auth flow: auth, auth_ok, auth_error
# - Tunnel management: tunnel_open, tunnel_ready, tunnel_close
# - Request proxying: request_start, request_body, response_start, response_body, response_end
# - WebSocket passthrough: ws_upgrade, ws_upgrade_ok, ws_upgrade_error, ws_frame, ws_close
# - TCP tunneling: tcp_open, tcp_open_ok, tcp_open_error, tcp_data, tcp_close
# - Keepalive: ping, pong

require "./protocol/message"
require "./protocol/messages/auth"
require "./protocol/messages/tunnel"
require "./protocol/messages/request"
require "./protocol/messages/websocket"
require "./protocol/messages/tcp"

module Sellia::Protocol
  # Re-export message types for convenience
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
  alias WebSocketUpgrade = Messages::WebSocketUpgrade
  alias WebSocketUpgradeOk = Messages::WebSocketUpgradeOk
  alias WebSocketUpgradeError = Messages::WebSocketUpgradeError
  alias WebSocketFrame = Messages::WebSocketFrame
  alias WebSocketClose = Messages::WebSocketClose
  alias TcpOpen = Messages::TcpOpen
  alias TcpOpenOk = Messages::TcpOpenOk
  alias TcpOpenError = Messages::TcpOpenError
  alias TcpData = Messages::TcpData
  alias TcpClose = Messages::TcpClose
end
