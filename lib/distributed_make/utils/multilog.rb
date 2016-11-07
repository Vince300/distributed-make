require "distributed_make/base"

require "logger"

module DistributedMake::Utils
  # Object that dispatches output to multiple Logger-compatible objects.
  class Multilog
    # @return [Array(Logger)] List of loggers currently in the dispatch group
    attr_reader :loggers

    # @param [Array(Logger)] loggers List of loggers to dispatch the output to
    def initialize(*loggers)
      @loggers = loggers
      @original_loggers = loggers.dup
    end

    # Adds a new logger to the current dispatch group.
    #
    # @param [Logger] logger Logger to add to the dispatch group
    # @return [Logger] Added logger
    def add_logger(logger)
      @loggers << logger
      logger
    end

    # Removes a logger from the current dispatch group
    #
    # @param [Logger] logger Logger to remove from the dispatch group
    # @return [Logger,nil] Removed logger or nil
    def remove_logger(logger)
      @loggers.delete(logger)
    end

    # Resets the dispatch group to the one originally provided to the Multilog instance.
    #
    # @return [Array(Logger)] Restored dispatch group.
    def reset
      @loggers = @original_loggers.dup
    end

    # Handles Logger method calls in order to dispatch them to the current group.
    #
    # Method calls that do not specify a progname will be redirected in order to do so.
    def method_missing(name, *args, &block)
      @loggers.each do |logger|
        begin
          if [:info, :debug, :warn, :error, :fatal].include? name
            # Redirect to add method and reference program name
            logger.add(Logger.const_get(name.to_s.upcase.to_sym), args[0], logname) # args[0] is message
          else
            # Plain redirect
            logger.send(name, *args, &block)
          end
        rescue DRb::DRbConnError => e
          # If a logger fails because of a DRb error, remove it
          remove_logger(logger)
        end
      end
    end

    # Name of the current logging instance. Requires `$LOGGER_NAME` to be set.
    # Returns `$LOGGER_NAME@hostname`.
    #
    # @return [String] String representing the current logging instance
    def logname
      @logname ||= "#{$LOGGER_NAME}@#{Socket.gethostname}"
    end
  end
end
