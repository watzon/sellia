require "http/web_socket"
require "http/client"
require "./protocol"

module Sellia
  class Client
    def initialize(@via : String, @via_port : Int32, @local_port : Int32, @subdomain : String)
    end

    def start
      url = "ws://#{@via}:#{@via_port}/_sellia/tunnel?subdomain=#{@subdomain}"
      puts "Connecting to #{url}..."

      ws = HTTP::WebSocket.new(URI.parse(url))

      ws.on_message do |message|
        spawn do
          handle_request(ws, message)
        end
      end

      ws.on_close do |code, message|
        puts "Disconnected: #{message} (#{code})"
        exit 1
      end

      puts "Tunnel established! forwarding #{@subdomain}.#{@via} -> localhost:#{@local_port}"
      ws.run
    rescue ex
      puts "Error connecting: #{ex.message}"
      exit 1
    end

    private def handle_request(ws : HTTP::WebSocket, message : String)
      begin
        request = Protocol::Request.from_json(message)

        # Forward to local service
        # We need to reconstruct the request

        headers = HTTP::Headers.new
        request.headers.each do |key, values|
          values.each { |v| headers.add(key, v) }
        end

        # Override Host header to localhost to avoid confusion for the local server
        headers["Host"] = "localhost:#{@local_port}"

        local_url = "http://localhost:#{@local_port}#{request.path}"

        # Perform the request
        # Using HTTP::Client directly for full control

        client = HTTP::Client.new("localhost", @local_port)
        response = client.exec(request.method, request.path, headers, request.body)
        client.close

        # Send response back
        resp_headers = Hash(String, Array(String)).new
        response.headers.each do |key, values|
          resp_headers[key] = values
        end

        resp_proto = Protocol::Response.new(
          id: request.id,
          status_code: response.status_code,
          headers: resp_headers,
          body: response.body
        )

        ws.send(resp_proto.to_json)
      rescue ex
        puts "Error handling request: #{ex.message}"
        # Ideally send an error response back to the server so the proxy doesn't hang
        # But we might not have the request ID if parsing failed
      end
    end
  end
end
