require "../message"

module Sellia::Protocol::Messages
  # Start of an HTTP request being proxied
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

  # Request body chunk
  class RequestBody < Message
    property type : String = "request_body"
    property request_id : String
    property chunk : Bytes
    property final : Bool

    def initialize(@request_id : String, @chunk : Bytes, @final : Bool = false)
    end
  end

  # Start of response from local service
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

  # Response body chunk
  class ResponseBody < Message
    property type : String = "response_body"
    property request_id : String
    property chunk : Bytes

    def initialize(@request_id : String, @chunk : Bytes)
    end
  end

  # End of response
  class ResponseEnd < Message
    property type : String = "response_end"
    property request_id : String

    def initialize(@request_id : String)
    end
  end

  # Keepalive ping
  class Ping < Message
    property type : String = "ping"
    property timestamp : Int64

    def initialize(@timestamp : Int64 = Time.utc.to_unix_ms)
    end
  end

  # Keepalive pong
  class Pong < Message
    property type : String = "pong"
    property timestamp : Int64

    def initialize(@timestamp : Int64 = Time.utc.to_unix_ms)
    end
  end
end
