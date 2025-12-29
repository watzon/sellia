require "http/server"
require "mutex"
require "log"

module Sellia::Server
  class PendingRequest
    Log = ::Log.for("sellia.server.pending")
    property id : String
    property context : HTTP::Server::Context
    property tunnel_id : String
    property created_at : Time
    property response_started : Bool
    property channel : Channel(Nil)
    @closed : Bool = false

    def initialize(@id : String, @context : HTTP::Server::Context, @tunnel_id : String)
      @created_at = Time.utc
      @response_started = false
      @channel = Channel(Nil).new
    end

    def start_response(status_code : Int32, headers : Hash(String, Array(String)))
      return if @closed
      @response_started = true
      @context.response.status_code = status_code
      headers.each do |key, values|
        values.each { |value| @context.response.headers.add(key, value) }
      end
    rescue ex : IO::Error
      # Client disconnected (Caddy canceled, browser navigated away, etc.)
      @closed = true
    end

    def write_body(chunk : Bytes)
      return if @closed
      @context.response.write(chunk)
      @context.response.flush
    rescue ex : IO::Error
      # Client disconnected - mark as closed so subsequent writes are skipped
      Log.debug { "Write failed for request #{@id}: #{ex.message} - marking as closed" }
      @closed = true
    end

    def finish
      begin
        @context.response.close
      rescue
        # Response may already be closed
      end
      begin
        @channel.send(nil)
      rescue Channel::ClosedError
        # Channel may already be closed
      end
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
      # Only set status/headers if response hasn't started yet and not already closed
      unless @response_started || @closed
        begin
          @context.response.status_code = status
          @context.response.content_type = "text/plain"
          @context.response.print(message)
        rescue ex : IO::Error
          @closed = true
        end
      end
      begin
        @context.response.close
      rescue
        # Response may already be closed
      end
      begin
        @channel.send(nil)
      rescue Channel::ClosedError
        # Channel may already be closed
      end
    end
  end

  class PendingRequestStore
    def initialize(@request_timeout : Time::Span = 30.seconds)
      @requests = {} of String => PendingRequest
      @mutex = Mutex.new
      spawn_cleanup_loop
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

    # Remove all pending requests for a tunnel and send 502 error
    def remove_by_tunnel(tunnel_id : String) : Int32
      @mutex.synchronize do
        removed = 0
        @requests.reject! do |_, request|
          if request.tunnel_id == tunnel_id
            # Signal error to waiting handler
            spawn { request.error(502, "Tunnel disconnected") }
            removed += 1
            true
          else
            false
          end
        end
        removed
      end
    end

    def size : Int32
      @mutex.synchronize { @requests.size }
    end

    private def spawn_cleanup_loop
      spawn do
        loop do
          sleep 10.seconds
          cleanup_stale_requests
        end
      end
    end

    # Clean up requests that have exceeded their timeout
    private def cleanup_stale_requests
      @mutex.synchronize do
        cutoff = Time.utc - @request_timeout - 5.seconds
        @requests.reject! do |_, request|
          if request.created_at < cutoff
            # Signal timeout to waiting handler (they may already be gone)
            spawn do
              begin
                request.error(504, "Gateway timeout (cleanup)")
              rescue
                # Response may already be closed
              end
            end
            true
          else
            false
          end
        end
      end
    end
  end
end
