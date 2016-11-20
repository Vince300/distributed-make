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

    # @return [Bool] `true` if unsafe mode is enabled
    def unsafe?
      @unsafe
    end

    # @return [Integer] Maximum number of concurrent connections to file engines
    def file_concurrency
      @file_concurrency
    end

    # @param [String] name the job's name
    # @param [Bool] dry_run `true` to enable dry-run
    # @param [Integer] period Rinda service period to use as timeout base
    # @param [Bool] unsafe `true` if unsafe mode is enabled
    # @param [Integer] file_concurrency Maximum number of concurrent connections to file engines
    def initialize(name, dry_run, period, unsafe, file_concurrency)
      @name = name
      @dry_run = dry_run
      @period = period
      @unsafe = unsafe
      @file_concurrency = file_concurrency
    end
  end
end
