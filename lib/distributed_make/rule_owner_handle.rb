require "drb/drb"

module DistributedMake
  # A distributed object which is able to update the next task of a given worker
  class RuleOwnerHandle
    include DRbUndumped

    # Sets the next rule for the worker to process
    #
    # @param [Array] tuple tuple matching the available task format
    def set_next_rule(tuple)
      @callback.call(tuple)
    end

    # Obtains the handle and resets the next tuple
    #
    # @return [RuleOwnerHandle] the handle itself
    def handle
      # clear out the current rule
      @callback.call(nil)
      self
    end

    # @yieldparam [Rule] rule rule to be processed next instead of querying the tuple space
    def initialize(&callback)
      @callback = callback
    end
  end
end
