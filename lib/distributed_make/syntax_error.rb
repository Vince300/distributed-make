require "distributed_make/base"
require "distributed_make/error"

module DistributedMake
  # Represents an error that occurs because a Makefile has not been written properly.
  #
  # @attr_reader [String] file Name of the file that raised this error.
  # @attr_reader [Fixnum] line Line in the file at which this error occurred.
  # @attr_reader [Fixnum] column Column in the file at which this error occurred.
  # @attr_reader [String] reason Message describing the error that occurred, such as duplicate rule definition or circular dependency.
class SyntaxError < Error
    attr_reader :file, :line, :column, :reason

    # Initialize a new instance of the @see DistributedMake::SyntaxError class.
    #
    # @param [String] file Name of the file that raised this error.
    # @param [Fixnum] line Line in the file at which this error occurred.
    # @param [Fixnum] column Column in the file at which this error occurred.
    # @param [String] reason Message describing the error that occurred, such as duplicate rule definition or circular dependency.
    def initialize(reason, line, column, file)
      @reason = reason
      @line = line
      @column = column
      @file = file || "(no source)"
    end

    # Error message that explains why and where this error occurred.
    #
    # @return [String]
    def message
      "#{file}:#{line}:#{column}: #{reason}"
    end
  end
end
