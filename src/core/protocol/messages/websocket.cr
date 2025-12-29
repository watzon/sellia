require "../message"

module Sellia::Protocol::Messages
  # Server -> Client: Incoming WebSocket upgrade request
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

  # Client -> Server: Local service accepted the WebSocket upgrade
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

  # Client -> Server: Local service rejected the WebSocket upgrade
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

  # Bidirectional: WebSocket frame data
  # opcode: 0x01=text, 0x02=binary, 0x08=close, 0x09=ping, 0x0A=pong
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

  # Bidirectional: WebSocket connection closed
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
end
