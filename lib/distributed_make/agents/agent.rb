require "distributed_make/base"

module DistributedMake::Agents
  # Base class for a distributed make agent
  #
  # @attr_accessor [Logger] logger Logger in use by this instance
  # @attr_accessor [Rinda::TupleSpace] ts Tuple space in use by this agent
  class Agent
    attr_accessor :logger, :ts

    protected
    # Initialize a new current tuple space
    #
    # @param [Rinda::TupleSpace] space New tuple space.
    def join_tuple_space(space)
      @ts = space

      # Reset services
      @services = {}
    end

    # Find a service by name
    #
    # @param [Symbol] name Name of the service
    # @return [Object] Service object instance
    def service(name)
      @services[name] || (@services[name] = ts.read([:service, name, nil])[2])
    end

    # Register a new service
    #
    # @param [Symbol] name Name of the service
    # @param [Object] service Service object
    def register_service(name, service)
      ts.write([:service, name, service])
      @services[name] = service
    end

    # Create a new agent.
    #
    # @param [Logger] logger Logger to use for this instance.
    def initialize(logger)
      @logger = logger
    end

    # Start the dRuby service on the given host.
    #
    # @param [String, nil] host Hostname to use for dRuby service.
    def start_drb(host)
      url = nil

      unless host.nil?
        # Add port if missing
        host = "#{host}:0" unless host =~ /:[0-9]+$/

        # Build dRuby URL
        url = "druby://#{host}"
      end

      @logger.info("starting DRb at #{url || 'the default location'}")

      # Start service
      DRb.start_service(url)

      @logger.info("started DRb at #{DRb.uri}")
    end
  end
end
