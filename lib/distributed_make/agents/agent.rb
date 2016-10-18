require "distributed_make/base"

module DistributedMake::Agents
  # Base class for a distributed make agent
  #
  # @attr_accessor [Logger] logger Logger in use by this instance
  class Agent
    attr_accessor :logger

    protected
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

        # Start service
        DRb.start_service(url)
        @logger.info("started DRb at #{DRb.uri}")
      end
  end
end
