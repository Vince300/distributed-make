require "distributed_make/base"
require "distributed_make/error"

module DistributedMake
  # Represents an error that occurs because a Makefile has not been constructed properly.
  #
  # @attr_reader [String] file Name of the file that raised this error.
  # @attr_reader [Fixnum] line Line in the file at which this error occurred.
  # @attr_reader [String] reason Message describing the error that occurred, such as duplicate rule definition or circular dependency.
  class MakefileError < Error
    attr_reader :file, :line, :reason

    # @param [String] reason the reason this error occurred
    # @param [Fixnum] line the line at which this error occurred.
    # @param [String] file name of the file which raised this error.
    def initialize(reason, line, file)
      @reason = reason
      @line = line
      @file = file || "(no source)"
    end

    # Error message that explains why and where this error occurred.
    #
    # @return [String]
    def message
      "#{file}:#{line}: #{reason}"
    end
  end
end
