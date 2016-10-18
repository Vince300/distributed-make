require "distributed_make/base"
require "distributed_make/agents/agent"

require "drb/drb"
require "rinda/ring"

module DistributedMake::Agents
  # Represents a distributed make system worker.
  class Worker < Agent
    # Run the driver agent on the given host.
    #
    # @param [String, nil] host Hostname for the dRuby service.
    def run(host = nil)
      @logger.debug("begin #{__method__.to_s}")

      # Start DRb service
      start_drb(host)

      # Locate tuple space
      @ts = Rinda::RingFinger.primary
      @logger.info("located tuple space #{@ts}")

      # Wait for work
      DRb.thread.join

      @logger.debug("end #{__method__.to_s}")
    end
  end
end
