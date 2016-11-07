require "distributed_make/base"

module DistributedMake::Services
  # A service that holds various information about the current job being processed.
  class JobService
    # @return [String] the job's name
    attr_reader :name

    # @return [Integer] Rinda service period to use as timeout base
    attr_reader :period

    # @return [Bool] `true` if dry-run mode is enabled
    def dry_run?
      @dry_run
    end

    # @param [String] name the job's name
    # @param [Bool] dry_run `true` to enable dry-run
    # @param [Integer] period Rinda service period to use as timeout base
    def initialize(name, dry_run, period)
      @name = name
      @dry_run = dry_run
      @period = period
    end
  end
end
