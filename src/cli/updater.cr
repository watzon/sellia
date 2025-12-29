require "http/client"
require "json"
require "file_utils"
require "../core/version"

module Sellia::CLI
  class Updater
    REPO            = "watzon/sellia"
    GITHUB_API      = "https://api.github.com"
    GITHUB_DOWNLOAD = "https://github.com"

    struct Release
      include JSON::Serializable

      property tag_name : String
      property assets : Array(Asset)

      struct Asset
        include JSON::Serializable

        property name : String
        property browser_download_url : String
      end
    end

    property check_only : Bool
    property force : Bool
    property target_version : String?

    def initialize(@check_only = false, @force = false, @target_version = nil)
    end

    def run
      current = Sellia::VERSION
      puts "#{"Current:".colorize(:white).bold} v#{current}"

      # Fetch release info
      release = fetch_release
      if release.nil?
        STDERR.puts "#{"Error:".colorize(:red).bold} Failed to fetch release information"
        return false
      end

      latest = release.tag_name.lstrip('v')
      puts "#{"Latest:".colorize(:white).bold}  v#{latest}"
      puts ""

      # Compare versions
      if !@force && current == latest
        puts "#{"Already up to date".colorize(:green)} (v#{current})"
        return true
      end

      if @check_only
        if compare_versions(latest, current) > 0
          puts "Run #{"sellia update".colorize(:cyan)} to install v#{latest}"
        else
          puts "#{"Already up to date".colorize(:green)}"
        end
        return true
      end

      # Find the right asset for this platform
      asset = find_asset(release)
      if asset.nil?
        STDERR.puts "#{"Error:".colorize(:red).bold} No binary available for this platform"
        STDERR.puts "Platform: #{os_name}-#{arch_name}"
        return false
      end

      # Perform update
      print "Updating... "
      STDOUT.flush

      if perform_update(asset)
        puts "#{"Done!".colorize(:green)}"
        puts ""
        puts "Updated to #{"v#{latest}".colorize(:cyan).bold}"
        true
      else
        puts "#{"Failed".colorize(:red)}"
        false
      end
    end

    private def fetch_release : Release?
      url = if version = @target_version
              # Ensure version starts with 'v'
              v = version.starts_with?('v') ? version : "v#{version}"
              "#{GITHUB_API}/repos/#{REPO}/releases/tags/#{v}"
            else
              "#{GITHUB_API}/repos/#{REPO}/releases/latest"
            end

      headers = HTTP::Headers.new
      headers["Accept"] = "application/vnd.github.v3+json"
      headers["User-Agent"] = "sellia/#{Sellia::VERSION}"

      response = HTTP::Client.get(url, headers: headers)

      if response.status_code == 200
        Release.from_json(response.body)
      elsif response.status_code == 404 && @target_version
        STDERR.puts "#{"Error:".colorize(:red).bold} Version #{@target_version} not found"
        nil
      else
        nil
      end
    rescue ex
      STDERR.puts "#{"Error:".colorize(:red).bold} #{ex.message}"
      nil
    end

    private def find_asset(release : Release) : Release::Asset?
      expected_name = "sellia-#{os_name}-#{arch_name}"
      expected_name += ".exe" if os_name == "windows"

      release.assets.find { |a| a.name == expected_name }
    end

    private def os_name : String
      {% if flag?(:darwin) %}
        "darwin"
      {% elsif flag?(:linux) %}
        "linux"
      {% elsif flag?(:windows) %}
        "windows"
      {% else %}
        "unknown"
      {% end %}
    end

    private def arch_name : String
      {% if flag?(:x86_64) || flag?(:amd64) %}
        "amd64"
      {% elsif flag?(:aarch64) || flag?(:arm64) %}
        "arm64"
      {% else %}
        "unknown"
      {% end %}
    end

    private def perform_update(asset : Release::Asset) : Bool
      # Get current executable path
      exe_path = Process.executable_path
      if exe_path.nil?
        STDERR.puts "\n#{"Error:".colorize(:red).bold} Cannot determine executable path"
        return false
      end

      # Download to temp file
      tmp_file = File.tempfile("sellia-update") do |file|
        HTTP::Client.get(asset.browser_download_url) do |response|
          if response.status_code == 302 || response.status_code == 301
            # Follow redirect
            redirect_url = response.headers["Location"]?
            if redirect_url
              HTTP::Client.get(redirect_url) do |redirect_response|
                IO.copy(redirect_response.body_io, file)
              end
            else
              return false
            end
          elsif response.status_code == 200
            IO.copy(response.body_io, file)
          else
            return false
          end
        end
      end

      {% if flag?(:windows) %}
        # Windows: rename current to .old, copy new, clean up on next run
        old_path = "#{exe_path}.old"
        File.delete(old_path) if File.exists?(old_path)
        File.rename(exe_path, old_path)
        FileUtils.mv(tmp_file.path, exe_path)
        # Schedule old file for deletion (best effort)
        spawn do
          sleep 1.second
          File.delete(old_path) rescue nil
        end
      {% else %}
        # Unix: can replace while running
        File.chmod(tmp_file.path, 0o755)
        FileUtils.mv(tmp_file.path, exe_path)
      {% end %}

      true
    rescue ex
      STDERR.puts "\n#{"Error:".colorize(:red).bold} #{ex.message}"
      false
    end

    private def compare_versions(a : String, b : String) : Int32
      a_parts = a.split('.').map(&.to_i)
      b_parts = b.split('.').map(&.to_i)

      # Pad shorter array with zeros
      max_len = {a_parts.size, b_parts.size}.max
      a_parts += [0] * (max_len - a_parts.size)
      b_parts += [0] * (max_len - b_parts.size)

      a_parts.zip(b_parts) do |a_part, b_part|
        cmp = a_part <=> b_part
        return cmp if cmp != 0
      end

      0
    end
  end
end
