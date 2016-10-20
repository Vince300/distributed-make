require "distributed_make/base"

module DistributedMake::Utils
  class SimpleRenewer
    include DRbUndumped

    def initialize(sec)
      @sec = sec
    end

    def renew
      @sec
    end
  end
end
