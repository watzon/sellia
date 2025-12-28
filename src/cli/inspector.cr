require "http/server"
require "http/client"
require "http/web_socket"
require "json"
require "log"
require "./request_store"

module Sellia::CLI
  # The Inspector provides a web UI for viewing tunneled HTTP requests in real-time.
  # It serves the React UI and provides WebSocket and REST endpoints for request data.
  class Inspector
    Log = ::Log.for(self)

    property port : Int32
    property store : RequestStore

    @server : HTTP::Server?
    @running : Bool = false

    def initialize(@port : Int32, @store : RequestStore)
    end

    # Start the inspector HTTP server
    def start
      @running = true

      server = HTTP::Server.new do |context|
        handle_request(context)
      end

      @server = server

      begin
        address = server.bind_tcp("127.0.0.1", @port)
        Log.info { "Inspector running at http://#{address}" }
        server.listen
      rescue ex : Socket::BindError
        Log.error { "Failed to bind inspector to port #{@port}: #{ex.message}" }
        @running = false
      end
    end

    # Stop the inspector server
    def stop
      @running = false
      @server.try(&.close)
    end

    # Check if the inspector is running
    def running? : Bool
      @running
    end

    private def handle_request(context : HTTP::Server::Context)
      path = context.request.path

      # CORS headers for development
      context.response.headers["Access-Control-Allow-Origin"] = "*"
      context.response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
      context.response.headers["Access-Control-Allow-Headers"] = "Content-Type"

      if context.request.method == "OPTIONS"
        context.response.status_code = 204
        return
      end

      case path
      when "/api/live"
        handle_websocket(context)

      when "/api/requests"
        handle_requests_api(context)

      when "/api/requests/clear"
        handle_clear_api(context)

      when "/"
        serve_index(context)

      else
        # Serve static assets
        serve_static(context, path)
      end
    end

    private def handle_websocket(context : HTTP::Server::Context)
      # Check for WebSocket upgrade
      if context.request.headers["Upgrade"]?.try(&.downcase) == "websocket"
        ws_handler = HTTP::WebSocketHandler.new do |socket, ctx|
          handle_websocket_connection(socket)
        end
        ws_handler.call(context)
      else
        context.response.status_code = 400
        context.response.content_type = "text/plain"
        context.response.print("WebSocket connection required")
      end
    end

    private def handle_websocket_connection(socket : HTTP::WebSocket)
      Log.debug { "WebSocket client connected to inspector" }

      channel = @store.subscribe

      # Send updates to WebSocket client
      spawn do
        loop do
          select
          when request = channel.receive
            begin
              message = {type: "request", request: request}.to_json
              socket.send(message)
            rescue
              break
            end
          end
        end
      end

      socket.on_close do
        Log.debug { "WebSocket client disconnected from inspector" }
        @store.unsubscribe(channel)
      end

      socket.run
    end

    private def handle_requests_api(context : HTTP::Server::Context)
      context.response.content_type = "application/json"
      context.response.print(@store.all.to_json)
    end

    private def handle_clear_api(context : HTTP::Server::Context)
      if context.request.method == "POST"
        @store.clear
        context.response.content_type = "application/json"
        context.response.print(%({"status":"ok"}))
      else
        context.response.status_code = 405
        context.response.print("Method not allowed")
      end
    end

    private def serve_index(context : HTTP::Server::Context)
      {% if flag?(:embed_assets) %}
        serve_embedded_index(context)
      {% else %}
        proxy_to_vite(context, "/")
      {% end %}
    end

    private def serve_static(context : HTTP::Server::Context, path : String)
      {% if flag?(:embed_assets) %}
        serve_embedded_asset(context, path)
      {% else %}
        proxy_to_vite(context, path)
      {% end %}
    end

    {% if flag?(:embed_assets) %}
      # Embedded assets for production builds
      EMBEDDED_INDEX = {{ read_file("#{__DIR__}/../../web/dist/index.html") }}

      # Read all assets from the dist/assets directory at compile time
      {% assets_dir = "#{__DIR__}/../../web/dist/assets" %}
      {% asset_files = `ls #{assets_dir.id} 2>/dev/null`.strip.split("\n") %}

      EMBEDDED_ASSETS = {
        {% for file in asset_files %}
          {% if file.size > 0 %}
            "/assets/{{ file.id }}" => {{ read_file("#{assets_dir.id}/#{file.id}") }},
          {% end %}
        {% end %}
      } of String => String

      private def serve_embedded_index(context : HTTP::Server::Context)
        context.response.content_type = "text/html; charset=utf-8"
        context.response.print(EMBEDDED_INDEX)
      end

      private def serve_embedded_asset(context : HTTP::Server::Context, path : String)
        if content = EMBEDDED_ASSETS[path]?
          # Determine content type from extension
          content_type = case path
          when .ends_with?(".js")
            "application/javascript; charset=utf-8"
          when .ends_with?(".css")
            "text/css; charset=utf-8"
          when .ends_with?(".svg")
            "image/svg+xml"
          when .ends_with?(".png")
            "image/png"
          when .ends_with?(".jpg"), .ends_with?(".jpeg")
            "image/jpeg"
          when .ends_with?(".woff"), .ends_with?(".woff2")
            "font/woff2"
          when .ends_with?(".json")
            "application/json"
          else
            "application/octet-stream"
          end

          context.response.content_type = content_type
          context.response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
          context.response.print(content)
        else
          context.response.status_code = 404
          context.response.content_type = "text/plain"
          context.response.print("Not found: #{path}")
        end
      end
    {% else %}
      # Development mode: proxy to Vite dev server
      VITE_HOST = "localhost"
      VITE_PORT = 5173

      private def proxy_to_vite(context : HTTP::Server::Context, path : String)
        begin
          vite_url = "http://#{VITE_HOST}:#{VITE_PORT}#{path}"

          # Handle WebSocket upgrade for Vite HMR
          if context.request.headers["Upgrade"]?.try(&.downcase) == "websocket"
            # For WebSocket, we can't easily proxy, so return an error
            context.response.status_code = 502
            context.response.print("WebSocket proxying not supported for Vite HMR. Use direct connection.")
            return
          end

          response = HTTP::Client.get(vite_url)
          context.response.status_code = response.status_code

          # Forward relevant headers
          response.headers.each do |key, values|
            next if key.downcase.in?("transfer-encoding", "connection", "content-length")
            context.response.headers[key] = values.first
          end

          context.response.print(response.body)
        rescue ex : Socket::ConnectError
          serve_vite_not_running_error(context)
        rescue ex
          context.response.status_code = 502
          context.response.content_type = "text/plain"
          context.response.print("Proxy error: #{ex.message}")
        end
      end

      private def serve_vite_not_running_error(context : HTTP::Server::Context)
        context.response.status_code = 503
        context.response.content_type = "text/html; charset=utf-8"
        context.response.print(<<-HTML)
        <!DOCTYPE html>
        <html>
        <head>
          <title>Sellia Inspector - Dev Server Not Running</title>
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              background: #111827;
              color: #f3f4f6;
              display: flex;
              justify-content: center;
              align-items: center;
              min-height: 100vh;
              margin: 0;
            }
            .container {
              max-width: 500px;
              padding: 2rem;
              text-align: center;
            }
            h1 { color: #ef4444; }
            code {
              background: #374151;
              padding: 0.5rem 1rem;
              border-radius: 0.25rem;
              display: block;
              margin: 1rem 0;
            }
            p { color: #9ca3af; }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Vite Dev Server Not Running</h1>
            <p>Start the Vite development server:</p>
            <code>cd web && npm run dev</code>
            <p>Or build for production:</p>
            <code>just build</code>
          </div>
        </body>
        </html>
        HTML
      end
    {% end %}
  end
end
