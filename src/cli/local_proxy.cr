require "http/client"
require "http/headers"

module Sellia::CLI
  # LocalProxy forwards HTTP requests to a local service.
  # It handles making the actual HTTP request to the local server
  # and returns the response status, headers, and body.
  class LocalProxy
    property host : String
    property port : Int32

    def initialize(@host : String = "localhost", @port : Int32 = 3000)
    end

    # Forward an HTTP request to the local service.
    # Returns a tuple of (status_code, response_headers, response_body_io)
    # Optional host and port parameters allow routing to a different target.
    def forward(
      method : String,
      path : String,
      headers : Hash(String, Array(String)),
      body : IO?,
      host : String? = nil,
      port : Int32? = nil,
    ) : {Int32, Hash(String, Array(String)), IO}
      target_host = host || @host
      target_port = port || @port

      # Build HTTP::Headers from hash, filtering hop-by-hop headers
      http_headers = HTTP::Headers.new
      headers.each do |key, values|
        # Skip hop-by-hop headers that shouldn't be forwarded
        next if hop_by_hop_header?(key)
        values.each { |value| http_headers.add(key, value) }
      end

      # Make request to local service
      client = HTTP::Client.new(target_host, target_port)
      client.connect_timeout = 5.seconds
      client.read_timeout = 30.seconds

      begin
        response = execute_request(client, method, path, http_headers, body)

        # Convert response headers to hash, preserving all values
        response_headers = {} of String => Array(String)
        response.headers.each do |key, values|
          response_headers[key] = values
        end

        # Read the full body into memory before closing the client
        # This is necessary because body_io becomes invalid after client.close
        body_content = response.body
        body_io = IO::Memory.new(body_content)

        {response.status_code, response_headers, body_io.as(IO)}
      ensure
        client.close
      end
    rescue ex : Socket::ConnectError
      error_body = IO::Memory.new("Local service unavailable at #{target_host}:#{target_port}")
      {502, {"Content-Type" => ["text/plain"]}, error_body.as(IO)}
    rescue ex : IO::TimeoutError
      error_body = IO::Memory.new("Request to local service timed out")
      {504, {"Content-Type" => ["text/plain"]}, error_body.as(IO)}
    rescue ex
      error_body = IO::Memory.new("Proxy error: #{ex.message}")
      {500, {"Content-Type" => ["text/plain"]}, error_body.as(IO)}
    end

    private def execute_request(
      client : HTTP::Client,
      method : String,
      path : String,
      headers : HTTP::Headers,
      body : IO?,
    ) : HTTP::Client::Response
      case method.upcase
      when "GET"
        client.get(path, headers: headers)
      when "POST"
        client.post(path, headers: headers, body: body)
      when "PUT"
        client.put(path, headers: headers, body: body)
      when "PATCH"
        client.patch(path, headers: headers, body: body)
      when "DELETE"
        client.delete(path, headers: headers)
      when "HEAD"
        client.head(path, headers: headers)
      when "OPTIONS"
        client.options(path, headers: headers)
      else
        client.exec(method.upcase, path, headers: headers, body: body)
      end
    end

    private def hop_by_hop_header?(key : String) : Bool
      # These headers should not be forwarded as they are connection-specific
      key.downcase.in?(
        "connection",
        "keep-alive",
        "transfer-encoding",
        "te",
        "trailer",
        "upgrade",
        "proxy-authorization",
        "proxy-authenticate"
      )
    end
  end
end
