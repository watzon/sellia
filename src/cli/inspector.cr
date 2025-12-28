require "http/server"
require "http/client"
require "http/web_socket"
require "json"
require "log"
require "./request_store"

{% unless flag?(:release) %}
  # Development mode - no baked assets needed
{% else %}
  require "baked_file_system"
{% end %}

module Sellia::CLI
  {% if flag?(:release) %}
    # Baked assets for production builds
    class InspectorAssets
      extend BakedFileSystem
      bake_folder "../../web/dist", __DIR__
    end
  {% end %}

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
        serve_file(context, "/index.html")

      else
        serve_file(context, path)
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
      closed = Atomic(Bool).new(false)

      # Send updates to WebSocket client
      spawn do
        loop do
          break if closed.get
          begin
            select
            when request = channel.receive?
              break if request.nil? # Channel was closed
              message = {type: "request", request: request}.to_json
              socket.send(message)
            when timeout(1.second)
              # Check if we should exit
              next
            end
          rescue Channel::ClosedError
            break
          rescue
            break
          end
        end
      end

      socket.on_close do
        Log.debug { "WebSocket client disconnected from inspector" }
        closed.set(true)
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

    private def serve_file(context : HTTP::Server::Context, path : String)
      {% if flag?(:release) %}
        serve_baked_file(context, path)
      {% else %}
        proxy_to_vite(context, path)
      {% end %}
    end

    {% if flag?(:release) %}
      private def serve_baked_file(context : HTTP::Server::Context, path : String)
        # Try to get the file from baked assets
        file = InspectorAssets.get?(path)

        # If not found and not already index.html, try index.html (SPA fallback)
        if file.nil? && path != "/index.html" && !path.starts_with?("/assets/")
          file = InspectorAssets.get?("/index.html")
        end

        if file
          content_type = mime_type_for(path)
          context.response.content_type = content_type

          # Cache static assets aggressively
          if path.starts_with?("/assets/")
            context.response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
          end

          context.response.print(file.gets_to_end)
        else
          context.response.status_code = 404
          context.response.content_type = "text/plain"
          context.response.print("Not found: #{path}")
        end
      end

      private def mime_type_for(path : String) : String
        case path
        when .ends_with?(".html")
          "text/html; charset=utf-8"
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
        when .ends_with?(".gif")
          "image/gif"
        when .ends_with?(".ico")
          "image/x-icon"
        when .ends_with?(".woff")
          "font/woff"
        when .ends_with?(".woff2")
          "font/woff2"
        when .ends_with?(".ttf")
          "font/ttf"
        when .ends_with?(".json")
          "application/json"
        when .ends_with?(".map")
          "application/json"
        else
          "application/octet-stream"
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
            <code>shards build --release</code>
          </div>
        </body>
        </html>
        HTML
      end
    {% end %}
  end
end
