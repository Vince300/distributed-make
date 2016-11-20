require "distributed_make/base"

require "drb/drb"
require "thread"

module DistributedMake::Services
  # A service that holds information about commands to run for the defined targets
  class WorkersService
    include DRbUndumped

    # Indicates a new worker has joined the pool
    #
    # @param [String] worker_name String identifying the worker
    def joined(worker_name)
      logger.info("#{worker_name} joined the worker pool")
      @mtx.synchronize do
        @current_joined += 1
        @cv.signal
      end
    end

    # Blocks until `worker_count` workers have joined the pool
    #
    # @param [Integer] worker_count minimum number of workers required to continue
    def wait_for(worker_count)
      return if worker_count <= 0

      loop do
        break if @mtx.synchronize do
          if @current_joined >= worker_count
            true
          else
            @cv.wait(@mtx)
            false
          end
        end
      end
      return
    end

    # @param [Logger] logger Logger to report events to
    def initialize(logger)
      @current_joined = 0
      @logger = logger

      @mtx = Mutex.new
      @cv = ConditionVariable.new
    end

    private
    attr_reader :logger
  end
end
