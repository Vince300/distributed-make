require "distributed_make/base"
require "distributed_make/file_engine"

require "uri"

module DistributedMake
  module Agents
    # Base class for a distributed make agent.
    class Agent
      # @return [Logger] the logger in use by this instance
      attr_accessor :logger

      # @return [Rinda::TupleSpace] the tuple space in use by this agent
      attr_accessor :ts

      # @return [DistributedMake::FileEngine] file engine managing the shared files
      attr_accessor :file_engine

      protected
      # @param [Logger] logger logger to use for this instance
      def initialize(logger)
        @logger = logger
      end

      # Initialize a new current tuple space.
      #
      # @param [Rinda::TupleSpace] space new tuple space
      # @return [Rinda::TupleSpace] joined tuple space
      def join_tuple_space(space)
        # Reset services
        @services = {}
        # Load tuple space
        @ts = space
      end

      # Find a service by name. This method blocks until the service is available.
      #
      # @param [Symbol] name name of the service
      # @return [Object] service object instance
      def service(name)
        @services[name] || (@services[name] = ts.read([:service, name, nil])[2])
      end

      # Register a new service.
      #
      # @param [Symbol] name name of the service
      # @param [Object] service service object
      # @return [Object] registered service
      def register_service(name, service)
        ts.write([:service, name, service])
        @services[name] = service
      end

      # Start the dRuby service on the given host.
      #
      # @param [String, nil] host hostname to use for dRuby service
      # @return [void]
      def start_drb(host)
        url = nil

        unless host.nil?
          # Add port if missing
          host = "#{host}:0" unless host =~ /:[0-9]+$/

          # Build dRuby URL
          url = "druby://#{host}"
        end

        logger.info("starting DRb at #{url || 'the default location'}")

        # Start service
        DRb.start_service(url)

        logger.info("started DRb at #{DRb.uri}")
        return
      end

      # Stops the dRuby service.
      # @return [void]
      def stop_drb
        begin
          DRb.stop_service
        rescue
        end
        return
      end

      # @return [String] host identification string of the current agent. Only valid once DRb service has been started.
      def host
        URI.parse(DRb.uri).host
      end

      # Setups the file engine to manage file transfers when executing the given block
      #
      # @param [Integer] period Tuple space period to use for the file engine
      # @param [Boolean] worker true if this agent is a worker
      def with_file_engine(period, worker)
        # Create the file engine
        @file_engine = DistributedMake::FileEngine.new(host, ts, Dir.pwd, logger, period, worker)

        # Invoke the callback
        begin
          yield
        ensure
          @file_engine.terminate
          @file_engine = nil
        end
      end

      # Executes the given block while renewing a given tuple entry.
      #
      # @param [TupleEntry] entry Entry to manage
      # @return [Object] value returned by the block
      def with_renewer(entry)
        do_run = true
        thd = Thread.start do
          while do_run do
            entry.renew(service(:job).period)
            sleep(service(:job).period / 10.0)
          end
        end

        begin
          return yield
        ensure
          do_run = false
          thd.join
        end
      end

      # return [Bool] true if the make process is running in unsafe mode
      def unsafe?
        service(:job).unsafe?
      end
    end
  end
end
