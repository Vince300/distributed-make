require "distributed_make/base"

module DistributedMake
  class SyntaxError < StandardError
    attr_reader :file, :line, :column, :reason

    def initialize(reason, line, column, file)
      @reason = reason
      @line = line
      @column = column
      @file = file || "(no source)"
    end

    def message
      "#{file}:#{line}:#{column}: #{reason}"
    end
  end
end
