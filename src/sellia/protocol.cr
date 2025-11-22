require "json"

module Sellia
  module Protocol
    struct Request
      include JSON::Serializable

      property id : String
      property method : String
      property path : String
      property headers : Hash(String, Array(String))
      property body : String? # Base64 encoded if binary

      def initialize(@id, @method, @path, @headers, @body = nil)
      end
    end

    struct Response
      include JSON::Serializable

      property id : String
      property status_code : Int32
      property headers : Hash(String, Array(String))
      property body : String? # Base64 encoded if binary

      def initialize(@id, @status_code, @headers, @body = nil)
      end
    end
  end
end
