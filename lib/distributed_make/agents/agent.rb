require "distributed_make/base"

module DistributedMake::Agents
  # Base class for a distributed make agent.
  class Agent
    # @return [Logger] the logger in use by this instance
    attr_accessor :logger

    # @return [Rinda::TupleSpace] the tuple space in use by this agent
    attr_accessor :ts

    protected
    # Create a new agent.
    #
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
  end
end
