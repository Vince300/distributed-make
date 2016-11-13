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
    # @param [Boolean] worker true if this engine is running in a worker
    def initialize(host, ts, dir, logger, period, worker)
      @host = host
      @ts = ts
      @dir = dir
      @logger = logger
      @period = period
      @worker = worker
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
          ts.read([:file, file, host, nil], 0) # Try to find the file on the same host
        rescue Rinda::RequestExpiredError
          all_tuples = ts.read_all([:file, file, nil, nil])

          # Prefer loading the workers for file transfers instead of the driver
          if all_tuples.empty?
            ts.read([:file, file, nil, nil])
          else
            all_tuples.select { |t| t[3].worker? }.sample ||
              all_tuples.sample
          end
        end

        # Connection properties
        remote_host = target_tuple[2]
        agent = target_tuple[3]

        # Download everything from socket to local file
        started_at = Time.now
        File.open(File.join(dir, file), "wb") do |output|
          agent.get_data(host) do |data|
            output.write(data)
          end
        end

        ended_at = Time.now
        speed = File.size(file) / (ended_at - started_at)

        logger.info("downloaded #{file} from #{remote_host} in #{ended_at - started_at}s (#{speed / 1024} kB/s)")

        return file
      end
    end

    def publish(file)
      file = file.to_s unless file.is_a? String

      unless @published_files[file]
        logger.debug("publishing #{file}")

        # Keep the reference to the handle so the GC doesn't collect the object
        # References:
        #  @published_files -> handle -> renewer
        renewer = Utils::SimpleRenewer.new(period)
        handle = FileHandle.new(file, self, @worker, renewer)

        @published_files[file] = handle
        ts.write([:file, file, host, handle], renewer)
      end
    end
  end
end
