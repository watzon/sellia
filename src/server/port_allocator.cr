require "mutex"
require "log"

module Sellia::Server
  # Allocates and manages TCP ports for tunnels
  #
  # Supports two modes:
  # - Fixed range: allocates from a configurable range (e.g., 5000-6000)
  # - Random: allocates random ports from the OS ephemeral range (like ngrok)
  class PortAllocator
    Log = ::Log.for(self)

    struct Allocation
      property port : Int32
      property tunnel_id : String
      property allocated_at : Time

      def initialize(@port : Int32, @tunnel_id : String)
        @allocated_at = Time.utc
      end
    end

    enum Mode
      FixedRange
      Random
    end

    @mode : Mode
    @range_start : Int32
    @range_end : Int32
    @allocations : Hash(Int32, Allocation)
    @by_tunnel : Hash(String, Int32)
    @mutex : Mutex

    # Initialize with a port range
    # If range_start is 0, uses random allocation mode
    def initialize(range_start : Int32 = 0, range_end : Int32 = 0)
      if range_start == 0
        @mode = Mode::Random
        @range_start = 0
        @range_end = 0
      else
        @mode = Mode::FixedRange
        @range_start = range_start
        @range_end = range_end
      end

      @allocations = {} of Int32 => Allocation
      @by_tunnel = {} of String => Int32
      @mutex = Mutex.new
    end

    # Allocate a port for the given tunnel
    # Returns nil if no port is available (only in FixedRange mode)
    def allocate(tunnel_id : String) : Int32?
      @mutex.synchronize do
        # Check if tunnel already has a port
        if existing = @by_tunnel[tunnel_id]?
          return existing
        end

        port = case @mode
               when Mode::FixedRange
                 allocate_from_range
               when Mode::Random
                 allocate_random
               end

        if port
          @allocations[port] = Allocation.new(port, tunnel_id)
          @by_tunnel[tunnel_id] = port
          Log.debug { "Allocated port #{port} for TCP tunnel #{tunnel_id}" }
        end

        port
      end
    end

    # Release a port allocation
    def release(port : Int32) : Allocation?
      @mutex.synchronize do
        if allocation = @allocations.delete(port)
          @by_tunnel.delete(allocation.tunnel_id)
          Log.debug { "Released port #{port} from TCP tunnel #{allocation.tunnel_id}" }
          allocation
        end
      end
    end

    # Release all ports for a tunnel
    def release_tunnel(tunnel_id : String) : Allocation?
      @mutex.synchronize do
        if port = @by_tunnel.delete(tunnel_id)
          release(port)
        end
      end
    end

    # Get port for a tunnel
    def get_port(tunnel_id : String) : Int32?
      @mutex.synchronize { @by_tunnel[tunnel_id]? }
    end

    # Get tunnel for a port
    def get_tunnel(port : Int32) : String?
      @mutex.synchronize { @allocations[port]?.try(&.tunnel_id) }
    end

    # Check if port is allocated
    def allocated?(port : Int32) : Bool
      @mutex.synchronize { @allocations.has_key?(port) }
    end

    def size : Int32
      @mutex.synchronize { @allocations.size }
    end

    def mode : Mode
      @mode
    end

    private def allocate_from_range : Int32?
      # Try to find an unallocated port in range
      (@range_start..@range_end).each do |port|
        unless @allocations.has_key?(port)
          return port
        end
      end
      Log.warn { "No available ports in range #{@range_start}-#{@range_end}" }
      nil
    end

    private def allocate_random : Int32?
      # Try up to 100 times to find an available random port
      100.times do
        # Use a random port in the upper ephemeral range
        # Linux/macOS typically use 32768-60999
        port = Random::Secure.rand(32768..60999)

        unless @allocations.has_key?(port)
          return port
        end
      end

      Log.error { "Failed to allocate random port after 100 attempts" }
      nil
    end
  end
end
