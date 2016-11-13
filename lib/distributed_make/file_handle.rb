require "distributed_make/base"

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

  class FileHandle
    include DRbUndumped

    attr_reader :file
    attr_reader :file_engine

    def worker?
      !!@worker
    end

    def initialize(file, file_engine, worker, renewer)
      @file = file
      @file_engine = file_engine
      @worker = worker
      @renewer = renewer
    end

    def get_data(remote_host, &block)
      file_engine.logger.info("serving #{file} to #{remote_host}")

      # Dump the whole file to the given block
      File.open(File.join(file_engine.dir, file), "rb") do |input|
        BlockWriter.open(block) do |bl|
          IO.copy_stream(input, bl)
        end
      end

      return
    end
  end
end
