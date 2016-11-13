require "distributed_make/base"

module DistributedMake
  class FileHandle
    include DRbUndumped

    attr_reader :file
    attr_reader :file_engine

    def worker?
      !!@worker
    end

    def initialize(file, file_engine, worker)
      @file = file
      @file_engine = file_engine
      @worker = worker
    end

    def get_data(remote_host)
      file_engine.logger.info("serving #{file} to #{remote_host}")

      # Dump the whole file to the given block
      File.open(File.join(file_engine.dir, file), "rb") do |input|
        while not input.eof? do
          yield input.read(4096)
        end
      end

      return
    end
  end
end
