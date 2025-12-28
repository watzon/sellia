require "msgpack"

module Sellia::Protocol
  # Base class for all protocol messages
  # Uses MessagePack's discriminator pattern for polymorphic deserialization
  abstract class Message
    include MessagePack::Serializable

    # Type discriminator for polymorphic deserialization
    # This maps the "type" field value to the concrete message class
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

    # Abstract method that each message type must implement
    abstract def type : String
  end
end
