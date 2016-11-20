require 'distributed_make/file_engine'

module DistributedMake
  # Represents a file being shared in a tuple space
  class FileHandle
    include DRbUndumped

    # @return [String] absolute path to the file to be shared
    attr_reader :file

    # @param [String] file absolute path to the file represented by this handle
    # @param [FileEngine] file_engine parent file engine
    def initialize(file, file_engine)
      @file = file
      @file_engine = file_engine
    end

    # Transfers the file to the given block.
    #
    # @param [String] remote_host name of the host requesting the file, used for slot allocation
    # @yieldparam [String] data transferred data to be stored to the destination file
    # @return [Boolean, Symbol] true if the file transfer was accepted, or :prefer_other when this worker load is too important
    def get_data(remote_host, &block)
      can_transfer = file_engine.request_transfer

      if can_transfer
        begin
          # Dump the whole file to the given block
          File.open(file, "rb") do |input|
            buffer = ""
            while input.read(1048576, buffer) # 1MB read into reused buffer
              yield(buffer)
            end
          end
        ensure
          file_engine.complete_transfer
        end
        return true
      else
        return :prefer_other
      end
    end

    private
    attr_reader :file_engine
  end
end
