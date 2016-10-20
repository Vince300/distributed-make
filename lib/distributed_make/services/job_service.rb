require "distributed_make/base"

module DistributedMake::Services
  # A service that holds various information about the current job being processed.
  #
  # @attr_reader [String] name The job's name.
  # @attr_reader [Integer] period Rinda service period to use as timeout base.
  class JobService
    attr_reader :name, :period

    # Initialize a new instance of the JobService class.
    #
    # @param [String] name The job's name.
    # @param [Integer] period Rinda service period to use as timeout base.
    def initialize(name, period)
      @name = name
      @period = period
    end
  end
end
