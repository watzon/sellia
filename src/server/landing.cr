require "http/server"

{% if flag?(:release) %}
  require "baked_file_system"
{% end %}

module Sellia::Server
  {% if flag?(:release) %}
    # Baked assets for the landing page (production only)
    class LandingAssets
      extend BakedFileSystem
      bake_folder "public", __DIR__
    end
  {% end %}

  # Serves the landing page and static assets
  # In release mode: serves from baked filesystem
  # In dev mode: serves from disk
  module Landing
    extend self

    # Path to public directory (for dev mode)
    PUBLIC_DIR = File.join(__DIR__, "public")

    def serve(context : HTTP::Server::Context) : Bool
      path = context.request.path
      path = "/index.html" if path == "/"

      {% if flag?(:release) %}
        serve_baked(context, path)
      {% else %}
        serve_from_disk(context, path)
      {% end %}
    end

    {% if flag?(:release) %}
      private def serve_baked(context : HTTP::Server::Context, path : String) : Bool
        file = LandingAssets.get?(path)

        # SPA fallback - serve index.html for unknown paths (except assets)
        if file.nil? && !path.starts_with?("/assets/") && !has_extension?(path)
          file = LandingAssets.get?("/index.html")
        end

        if file
          context.response.content_type = mime_type_for(path)

          # Cache static assets
          if path.starts_with?("/assets/") || has_extension?(path)
            context.response.headers["Cache-Control"] = "public, max-age=86400"
          end

          context.response.print(file.gets_to_end)
          true
        else
          false
        end
      end
    {% else %}
      private def serve_from_disk(context : HTTP::Server::Context, path : String) : Bool
        # Sanitize path to prevent directory traversal
        safe_path = File.expand_path(File.join(PUBLIC_DIR, path))
        unless safe_path.starts_with?(PUBLIC_DIR)
          return false
        end

        # Try the exact path first
        file_path = safe_path

        # If not found and not an asset path, try SPA fallback
        if !File.exists?(file_path) && !path.starts_with?("/assets/") && !has_extension?(path)
          file_path = File.join(PUBLIC_DIR, "index.html")
        end

        if File.exists?(file_path) && File.file?(file_path)
          context.response.content_type = mime_type_for(path)

          # No caching in dev mode for easier iteration
          context.response.headers["Cache-Control"] = "no-cache"

          File.open(file_path, "rb") do |file|
            IO.copy(file, context.response)
          end
          true
        else
          false
        end
      end
    {% end %}

    private def has_extension?(path : String) : Bool
      ext = File.extname(path)
      !ext.empty? && ext != "."
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
      when .ends_with?(".webp")
        "image/webp"
      when .ends_with?(".avif")
        "image/avif"
      else
        "application/octet-stream"
      end
    end
  end
end
