require "distributed_make/base"

module DistributedMake
  class MakefileError < StandardError
    attr_reader :file, :line, :reason

    def initialize(reason, line, file)
      @reason = reason
      @line = line
      @file = file || "(no source)"
    end

    def message
      "#{file}:#{line}: #{reason}"
    end
  end
end
