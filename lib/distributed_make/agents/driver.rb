require "distributed_make/base"
require "distributed_make/agents/agent"

require "drb/drb"
require "rinda/tuplespace"
require "rinda/ring"

module DistributedMake::Agents
  # Represents a distributed make system driver.
  class Driver < Agent
    # Run the driver agent on the given host.
    #
    # @param [String, nil] host Hostname for the dRuby service.
    def run(host = nil, period = 5)
      logger.debug("begin #{__method__.to_s}")

      # Start DRb service
      start_drb(host)

      # Create the tuple space to be shared
      @ts = Rinda::TupleSpace.new(period)

      # Setup Ring server
      @server = Rinda::RingServer.new(@ts)
      logger.info("started ring server")

      begin
        # Wait for work
        DRb.thread.join
      rescue Interrupt => e
        logger.info("exiting")
      end

      logger.debug("end #{__method__.to_s}")
    end
  end
end
