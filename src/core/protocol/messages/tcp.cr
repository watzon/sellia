require "../message"

module Sellia::Protocol::Messages
  # Server -> Client: Incoming TCP connection on allocated port
  class TcpOpen < Message
    property type : String = "tcp_open"
    property connection_id : String
    property tunnel_id : String
    property remote_addr : String # Client IP:Port

    def initialize(@connection_id : String, @tunnel_id : String, @remote_addr : String)
    end
  end

  # Client -> Server: Local TCP connection established
  class TcpOpenOk < Message
    property type : String = "tcp_open_ok"
    property connection_id : String

    def initialize(@connection_id : String)
    end
  end

  # Client -> Server: Local TCP connection failed
  class TcpOpenError < Message
    property type : String = "tcp_open_error"
    property connection_id : String
    property message : String

    def initialize(@connection_id : String, @message : String)
    end
  end

  # Bidirectional: TCP data chunk
  class TcpData < Message
    property type : String = "tcp_data"
    property connection_id : String
    property data : Bytes

    def initialize(@connection_id : String, @data : Bytes)
    end
  end

  # Bidirectional: TCP connection closed
  class TcpClose < Message
    property type : String = "tcp_close"
    property connection_id : String
    property reason : String?

    def initialize(@connection_id : String, @reason : String? = nil)
    end
  end
end
