require "http/server"
require "baked_file_system"

module Sellia::Server
  # Baked assets for the landing page
  class LandingAssets
    extend BakedFileSystem
    bake_folder "public", __DIR__
  end

  # Serves the landing page and static assets from the baked filesystem
  module Landing
    extend self

    def serve(context : HTTP::Server::Context) : Bool
      path = context.request.path
      path = "/index.html" if path == "/"

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
      else
        "application/octet-stream"
      end
    end
  end
end
