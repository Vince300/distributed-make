module DistributedMake
  # Represents a file being shared in a tuple space
  class FileHandle
    include DRbUndumped

    # @return [String] absolute path to the file to be shared
    attr_reader :file

    # @param [String] file absolute path to the file represented by this handle
    def initialize(file)
      @file = file
    end

    # Transfers the file to the given block.
    #
    # @param [String] remote_host name of the host requesting the file, used for slot allocation
    # @yieldparam [String] data transferred data to be stored to the destination file
    # @return [void]
    def get_data(remote_host, &block)
      # Dump the whole file to the given block
      File.open(file, "rb") do |input|
        buffer = ""
        while input.read(1048576, buffer) # 1MB read into reused buffer
          yield(buffer)
        end
      end
      return
    end
  end
end
