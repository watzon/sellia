require "http/server"
require "ecr"

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

    # Render the index page ECR template
    ECR.def_to_s "#{__DIR__}/public/index.html.ecr"

    def serve(context : HTTP::Server::Context) : Bool
      path = context.request.path

      # Serve rendered index for root and /index.html
      if path == "/" || path == "/index.html"
        serve_index(context)
        return true
      end

      {% if flag?(:release) %}
        serve_baked(context, path)
      {% else %}
        serve_from_disk(context, path)
      {% end %}
    end

    private def serve_index(context : HTTP::Server::Context)
      context.response.content_type = "text/html; charset=utf-8"
      context.response.headers["Cache-Control"] = "no-cache"
      to_s(context.response)
    end

    {% if flag?(:release) %}
      private def serve_baked(context : HTTP::Server::Context, path : String) : Bool
        file = LandingAssets.get?(path)

        # SPA fallback - serve rendered index for unknown paths (except assets)
        if file.nil? && !path.starts_with?("/assets/") && !has_extension?(path)
          serve_index(context)
          return true
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

        # SPA fallback - serve rendered index for unknown paths (except assets)
        if !File.exists?(safe_path) && !path.starts_with?("/assets/") && !has_extension?(path)
          serve_index(context)
          return true
        end

        if File.exists?(safe_path) && File.file?(safe_path)
          context.response.content_type = mime_type_for(path)

          # No caching in dev mode for easier iteration
          context.response.headers["Cache-Control"] = "no-cache"

          File.open(safe_path, "rb") do |file|
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
