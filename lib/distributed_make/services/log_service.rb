require "distributed_make/base"

require "socket"
require "drb/drb"

module DistributedMake::Services
  # A service that redirects logging calls to the master process.
  class LogService
    # @return [Logger] Remote Logger instance to send log messages to.
    attr_reader :logger

    # @param [Logger] logger Underlying logger object
    def initialize(logger)
      @logger = DRbObject.new(logger)
    end
  end
end
