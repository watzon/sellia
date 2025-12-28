# Protocol message types for Sellia tunnel communication
#
# The protocol uses MessagePack for binary serialization with a "type" field
# as the discriminator for polymorphic deserialization.
#
# Message types:
# - Auth flow: auth, auth_ok, auth_error
# - Tunnel management: tunnel_open, tunnel_ready, tunnel_close
# - Request proxying: request_start, request_body, response_start, response_body, response_end
# - Keepalive: ping, pong

require "./protocol/message"
require "./protocol/messages/auth"
require "./protocol/messages/tunnel"
require "./protocol/messages/request"

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
end
