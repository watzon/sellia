require "http/server"
require "mutex"

module Sellia::Server
  class PendingRequest
    property id : String
    property context : HTTP::Server::Context
    property tunnel_id : String
    property created_at : Time
    property response_started : Bool
    property channel : Channel(Nil)

    def initialize(@id : String, @context : HTTP::Server::Context, @tunnel_id : String)
      @created_at = Time.utc
      @response_started = false
      @channel = Channel(Nil).new
    end

    def start_response(status_code : Int32, headers : Hash(String, String))
      @response_started = true
      @context.response.status_code = status_code
      headers.each do |key, value|
        @context.response.headers[key] = value
      end
    end

    def write_body(chunk : Bytes)
      @context.response.write(chunk)
      @context.response.flush
    end

    def finish
      @context.response.close
      @channel.send(nil)
    end

    def wait(timeout : Time::Span = 30.seconds) : Bool
      select
      when @channel.receive
        true
      when timeout(timeout)
        false
      end
    end

    def error(status : Int32, message : String)
      @context.response.status_code = status
      @context.response.content_type = "text/plain"
      @context.response.print(message)
      @context.response.close
      @channel.send(nil)
    end
  end

  class PendingRequestStore
    def initialize
      @requests = {} of String => PendingRequest
      @mutex = Mutex.new
    end

    def add(request : PendingRequest)
      @mutex.synchronize { @requests[request.id] = request }
    end

    def get(id : String) : PendingRequest?
      @mutex.synchronize { @requests[id]? }
    end

    def remove(id : String) : PendingRequest?
      @mutex.synchronize { @requests.delete(id) }
    end

    def size : Int32
      @mutex.synchronize { @requests.size }
    end
  end
end
