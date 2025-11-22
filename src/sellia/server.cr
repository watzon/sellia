require "http/server"
require "uuid"
require "./protocol"

module Sellia
  class Server
    def initialize(@host : String, @port : Int32)
      @tunnels = Hash(String, HTTP::WebSocket).new
      @pending_requests = Hash(String, Channel(Protocol::Response)).new
    end

    def start
      server = HTTP::Server.new([
        TunnelHandler.new(@tunnels, @pending_requests),
        ProxyHandler.new(@tunnels, @pending_requests, @host),
      ])

      address = server.bind_tcp(@host, @port)
      puts "Listening on http://#{address}"
      server.listen
    end

    class TunnelHandler
      include HTTP::Handler

      def initialize(@tunnels : Hash(String, HTTP::WebSocket), @pending_requests : Hash(String, Channel(Protocol::Response)))
      end

      def call(context)
        if context.request.path == "/_sellia/tunnel"
          websocket_upgrade(context)
        else
          call_next(context)
        end
      end

      private def websocket_upgrade(context)
        subdomain = context.request.query_params["subdomain"]?
        unless subdomain
          context.response.status_code = 400
          context.response.print "Missing subdomain"
          return
        end

        ws = HTTP::WebSocketHandler.new do |socket|
          puts "New tunnel connected: #{subdomain}"
          @tunnels[subdomain] = socket

          socket.on_message do |message|
            begin
              response = Protocol::Response.from_json(message)
              if channel = @pending_requests[response.id]?
                channel.send(response)
              end
            rescue ex
              puts "Error parsing response: #{ex.message}"
            end
          end

          socket.on_close do
            puts "Tunnel disconnected: #{subdomain}"
            @tunnels.delete(subdomain)
          end
        end

        ws.call(context)
      end
    end

    class ProxyHandler
      include HTTP::Handler

      def initialize(@tunnels : Hash(String, HTTP::WebSocket), @pending_requests : Hash(String, Channel(Protocol::Response)), @host : String)
      end

      def call(context)
        host_header = context.request.headers["Host"]?
        unless host_header
          context.response.status_code = 400
          context.response.print "Missing Host header"
          return
        end

        # Simple subdomain extraction: subdomain.host.com -> subdomain
        # This is naive and assumes the host matches exactly what was passed to CLI
        # A more robust solution would handle ports and different TLDs better
        clean_host = host_header.split(":").first
        subdomain = ""

        if clean_host == @host
          # Root domain
        elsif clean_host.ends_with?(".#{@host}")
          subdomain = clean_host[0...-(@host.size + 1)]
        else
          # Unknown host
          context.response.status_code = 404
          context.response.print "Not found"
          return
        end

        if subdomain.empty?
          context.response.print "Sellia Server Running"
          return
        end

        ws = @tunnels[subdomain]?
        unless ws
          context.response.status_code = 502
          context.response.print "Tunnel not found for subdomain: #{subdomain}"
          return
        end

        request_id = UUID.random.to_s
        response_channel = Channel(Protocol::Response).new
        @pending_requests[request_id] = response_channel

        # Read body
        body = context.request.body.try &.gets_to_end
        # In a real app we'd base64 encode if binary, for now assume text/utf8 or handle simple cases

        # Convert headers to Hash(String, Array(String))
        headers_hash = Hash(String, Array(String)).new
        context.request.headers.each do |key, values|
          headers_hash[key] = values
        end

        req_proto = Protocol::Request.new(
          id: request_id,
          method: context.request.method,
          path: context.request.resource,
          headers: headers_hash,
          body: body
        )

        ws.send(req_proto.to_json)

        # Set up a temporary listener for the response
        # Note: This is a bit tricky with a single WebSocket handler for all messages.
        # We need to multiplex. The WebSocket handler needs to dispatch to channels.
        # Let's refactor this slightly. The ProxyHandler needs to own the message dispatch loop or share it.
        # Actually, the TunnelHandler created the WS, but we need to listen to it.
        # A better design: The Server class manages the tunnels and their message loops.

        # REFACTOR: We can't easily wait for a response here if we don't have access to the WS message loop.
        # The WS handler in TunnelHandler is where `on_message` happens.
        # We need a way to route responses back to this fiber.

        # Let's use a shared registry for pending requests.

        # Wait for response
        select
        when response = response_channel.receive
          context.response.status_code = response.status_code
          response.headers.each do |key, values|
            values.each { |v| context.response.headers.add(key, v) }
          end
          context.response.print response.body if response.body
        when timeout(10.seconds)
          context.response.status_code = 504
          context.response.print "Gateway Timeout"
        end

        @pending_requests.delete(request_id)
      end
    end
  end
end
