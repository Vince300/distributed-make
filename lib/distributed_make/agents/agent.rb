require "distributed_make/base"
require "distributed_make/file_engine"
require "distributed_make/utils/simple_renewer"

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

      # Get the host identification string of the current agent. Only valid once DRb service has been started.
      def host
        URI.parse(DRb.uri).host
      end

      # Setups the file engine to manage file transfers when executing the given block
      #
      # @param [Integer] period Tuple space period to use for the file engine
      def with_file_engine(period)
        # Used when publishing :file tuples through publish
        @period = period

        # Start the process
        file_engine_process = IO.popen([RbConfig.ruby, $ENTRY_POINT, 'fileserver'])

        # Find out the URI to the distributed object
        url = file_engine_process.gets.strip
        file_engine_wrapper = DRbObject.new_with_uri(url)

        # Start the file engine
        lg = logger
        lg = lg.loggers.first if lg.respond_to? :loggers

        @file_engine = file_engine_wrapper.start(host, Dir.pwd, logger, period)
        @dispatcher_port = @file_engine.port

        # Publish the initial files
        @published_files = {}
        publish_all

        begin
          yield
        ensure
          logger.reset if logger.respond_to? :reset

          # We are done, stop the file process
          file_engine_wrapper.stop

          # Wait for the process to completely stop
          Process.wait(file_engine_process.pid)
        end
      end

      def get(file)
        return file if File.exist? file

        loop do
          # Find the file on the pool
          target_tuple = begin
            ts.read([:file, file, host, nil], 0)
          rescue Rinda::RequestExpiredError
            ts.read_all([:file, file, nil, nil]).sample ||
              ts.read([:file, file, nil, nil])
          end

          # Connect to the host dispatch
          remote_host = target_tuple[2]
          remote_port = target_tuple[3]

          result = file_engine.get(file, remote_host, remote_port)
          return result if result
        end
      end

      def publish_all
        pd = Pathname.new(".")
        Dir.glob('**').each do |match|
          publish Pathname.new(match).relative_path_from(pd)
        end
      end

      def publish(file)
        unless @published_files[file]
          logger.debug("publishing #{file}")
          @published_files[file] = true
          ts.write([:file, file, host, @dispatcher_port], Utils::SimpleRenewer.new(@period))
        end
      end

      def available?(file)
        File.exist? file
      end
    end
  end
end
