require "distributed_make/base"
require "distributed_make/error"

module DistributedMake
  # Represents an error that occurs because a Makefile references missing source files.
  #
  # @attr_reader [String] file Name of the file that raised this error.
  class SourceError < Error
    attr_reader :file

    # @param [String] file name of the file which raised this error.
    def initialize(file)
      @file = file
    end

    # Error message that explains why and where this error occurred.
    #
    # @return [String]
    def message
      "No rule to make target `#{@file}`"
    end
  end
end
