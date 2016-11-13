require "distributed_make/block_writer"

module DistributedMake
  # Represents a file being shared in a tuple space
  class FileHandle
    include DRbUndumped

    # @return [String] absolute path to the file to be shared
    attr_reader :file

    # @return [Boolean] `true` if this handle belongs to a worker process, `false` otherwise
    def worker?
      !!@worker
    end

    # @param [String] file absolute path to the file represented by this handle
    # @param [Boolean] worker `true` if this handle belongs to a worker process, `false` otherwise
    def initialize(file, worker)
      @file = file
      @worker = worker
    end

    # Transfers the file to the given block.
    #
    # @param [String] remote_host name of the host requesting the file, used for slot allocation
    # @yieldparam [String] data transferred data to be stored to the destination file
    # @return [void]
    def get_data(remote_host, &block)
      # Dump the whole file to the given block
      File.open(file, "rb") do |input|
        BlockWriter.open(block) do |bl|
          IO.copy_stream(input, bl)
        end
      end
      return
    end
  end
end
