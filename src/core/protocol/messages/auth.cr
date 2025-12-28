require "../message"

module Sellia::Protocol::Messages
  # Client authentication request
  class Auth < Message
    property type : String = "auth"
    property api_key : String

    def initialize(@api_key : String)
    end
  end

  # Successful authentication response
  class AuthOk < Message
    property type : String = "auth_ok"
    property account_id : String
    property limits : Hash(String, Int64)

    def initialize(@account_id : String, @limits : Hash(String, Int64) = {} of String => Int64)
    end
  end

  # Authentication error response
  class AuthError < Message
    property type : String = "auth_error"
    property error : String

    def initialize(@error : String)
    end
  end
end
