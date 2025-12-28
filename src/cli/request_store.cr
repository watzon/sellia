require "json"
require "mutex"

module Sellia::CLI
  # Represents a complete request/response pair for the inspector
  struct StoredRequest
    include JSON::Serializable

    @[JSON::Field(key: "id")]
    property id : String

    @[JSON::Field(key: "method")]
    property method : String

    @[JSON::Field(key: "path")]
    property path : String

    @[JSON::Field(key: "statusCode")]
    property status_code : Int32

    @[JSON::Field(key: "duration")]
    property duration : Int64 # milliseconds

    @[JSON::Field(key: "timestamp")]
    property timestamp : Time

    @[JSON::Field(key: "requestHeaders")]
    property request_headers : Hash(String, String)

    @[JSON::Field(key: "requestBody")]
    property request_body : String?

    @[JSON::Field(key: "responseHeaders")]
    property response_headers : Hash(String, String)

    @[JSON::Field(key: "responseBody")]
    property response_body : String?

    def initialize(
      @id : String,
      @method : String,
      @path : String,
      @status_code : Int32,
      @duration : Int64,
      @timestamp : Time,
      @request_headers : Hash(String, String),
      @request_body : String?,
      @response_headers : Hash(String, String),
      @response_body : String?,
    )
    end
  end

  # Circular buffer for storing requests with live update support
  class RequestStore
    MAX_REQUESTS = 1000

    def initialize
      @requests = [] of StoredRequest
      @mutex = Mutex.new
      @subscribers = [] of Channel(StoredRequest)
    end

    # Add a new request to the store and notify subscribers
    def add(request : StoredRequest)
      @mutex.synchronize do
        @requests.unshift(request)
        @requests = @requests[0, MAX_REQUESTS] if @requests.size > MAX_REQUESTS

        # Notify all active subscribers
        @subscribers.each do |ch|
          begin
            ch.send(request)
          rescue Channel::ClosedError
            # Channel was closed, will be cleaned up later
          end
        end
      end
    end

    # Get all stored requests
    def all : Array(StoredRequest)
      @mutex.synchronize { @requests.dup }
    end

    # Clear all stored requests
    def clear
      @mutex.synchronize { @requests.clear }
    end

    # Get the number of stored requests
    def size : Int32
      @mutex.synchronize { @requests.size }
    end

    # Subscribe to live request updates
    def subscribe : Channel(StoredRequest)
      ch = Channel(StoredRequest).new(100)
      @mutex.synchronize { @subscribers << ch }
      ch
    end

    # Unsubscribe from live updates
    def unsubscribe(ch : Channel(StoredRequest))
      @mutex.synchronize do
        @subscribers.delete(ch)
        ch.close rescue nil
      end
    end
  end
end
