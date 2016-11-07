require "distributed_make/base"

# Various utilities for the distributed make project.
module DistributedMake::Utils
  # Represents a distributed tuple renewer that expires when its host is not available anymore.
  #
  # Implements a fault detector whose timeout is based on the expiration value provided and the TupleSpace period.
  class SimpleRenewer
    include DRbUndumped

    # @param [Integer] sec Timeout in seconds of this renewer
    def initialize(sec)
      @sec = sec
    end

    def renew
      @sec
    end
  end
end
