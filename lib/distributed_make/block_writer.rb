require "io/like"

module DistributedMake
  class BlockWriter
    include IO::Like

    def initialize(block)
      @block = block
    end

    def unbuffered_write(data)
      @block.call(data)
      return data.length
    end

    def self.open(*args)
      b = BlockWriter.new(*args)
      begin
        yield(b)
      ensure
        b.close
      end
    end
  end
end
