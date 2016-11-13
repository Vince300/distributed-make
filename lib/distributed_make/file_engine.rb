require "distributed_make/base"
require "distributed_make/utils/simple_renewer"
require "distributed_make/file_handle"

require "thread"
require "socket"
require "resolv"

require "drb/drb"

module DistributedMake
  class FileEngine
    # @return [String] Hostname of the current engine
    attr_reader :host

    # @return [Rinda::TupleSpace] Tuple space to support file sharing
    attr_reader :ts

    # @return [String] Absolute path to the working directory managed by this instance
    attr_reader :dir

    # @return [Logger] Logger to report events to
    attr_reader :logger

    # @return [Integer] Tuple space period
    attr_reader :period

    # @param [String] host Hostname to use for the TCP server
    # @param [Rinda::TupleSpace] ts Tuple space to support file sharing
    # @param [String] dir Working directory to manage
    # @param [Logger] logger Logger to report events to
    # @param [Integer] period Tuple space period
    def initialize(host, ts, dir, logger, period)
      @host = host
      @ts = ts
      @dir = dir
      @logger = logger
      @period = period
      @published_files = {}
    end

    # @return [Bool] `true` if the file is available in the managed directory, `false` otherwise
    def available?(file)
      File.exist? File.join(dir, file)
    end

    # Makes a file available in the working directory by querying peers.
    # Returns immediately on available files.
    #
    # @param [String] file file name to request
    # @return [String] requested file name
    def get(file)
      # Skip files already downloaded
      return file if available? file

      loop do
        # Find the file on the pool
        target_tuple = begin
          ts.read([:file, file, host, nil], 0)
        rescue Rinda::RequestExpiredError
          ts.read_all([:file, file, nil, nil]).sample ||
            ts.read([:file, file, nil, nil])
        end

        # Connection properties
        remote_host = target_tuple[2]
        agent = target_tuple[3]

        # Download everything from socket to local file
        File.open(File.join(dir, file), "wb") do |output|
          agent.get_data(host) do |data|
            output.write(data)
          end
        end

        logger.info("completed download of #{file} from #{remote_host}")

        return file
      end
    end

    def publish(file)
      unless @published_files[file]
        logger.debug("publishing #{file}")
        @published_files[file] = true
        ts.write([:file, file, host, FileHandle.new(file, self)], Utils::SimpleRenewer.new(period))
      end
    end
  end
end
