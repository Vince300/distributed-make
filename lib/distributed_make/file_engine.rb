require "distributed_make/base"
require "distributed_make/utils/simple_renewer"

require "thread"
require "socket"
require "resolv"

require "drb/drb"

module DistributedMake
  class FileAgent
    include DRbUndumped

    attr_reader :file
    attr_reader :file_engine

    def initialize(file, file_engine)
      @file = file
      @file_engine = file_engine
    end

    def reserve_slot(remote_host)
      server = TCPServer.new(file_engine.host, 0)
      logger.info("#{remote_host} requested #{file}, serving now on #{server.addr[1]}")

      Thread.start do
        begin
          logger.info("waiting for connection from #{remote_host} for #{file}")
          # Accept the incoming connection
          sock = server.accept
          logger.info("accepted connection from #{remote_host}:#{sock.peeraddr[2]} for #{file}")

          # Dump the whole file to the socket
          File.open(File.join(dir, file), "rb") do |input|
            IO.copy_stream(input, sock)
          end

          # Close the socket
          sock.close
        rescue Error => e
          logger.fatal(e)
        ensure
          server.close
        end
      end

      # Return the server port
      server.addr[1]
    end

    private
    def logger
      file_engine.logger
    end
  end

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

        # Get a download slot to connect to
        remote_port = agent.reserve_slot(host)

        tries = 0

        s = begin
          TCPSocket.open(remote_host, remote_port)
        rescue Errno::ECONNREFUSED
          tries = tries + 1

          # Not supposed to happen, try to resolve the hostname and retry
          if tries == 1
            remote_host = Resolv.getaddress(remote_host)
            retry
          end
        end

        if tries > 1
          # We cannot connect to the host, try from another host
          #
          # If the connection fails because the host is down, its associated tuple will eventually disappear from the
          # space, so we will try to fetch the file from another host
          redo
        else
          logger.info("connected to download slot at #{remote_host}:#{remote_port}")
        end

        # Download everything from socket to local file
        File.open(File.join(dir, file), "wb") do |output|
          IO.copy_stream(s, output)
        end

        logger.info("completed download of #{file} from #{remote_host}")

        # Close socket
        s.close

        return file
      end
    end

    # Starts the file engine
    # @return [void]
    def start
      # Publish all files originally in the working directory
      publish_all
      return
    end

    # Stops the file engine
    # @return [void]
    def stop
      return
    end

    def publish(file)
      unless @published_files[file]
        logger.debug("publishing #{file}")
        @published_files[file] = true
        ts.write([:file, file, host, FileAgent.new(file, self)], Utils::SimpleRenewer.new(period))
      end
    end

    protected
    def publish_all
      pd = Pathname.new(dir)
      Dir.glob(File.join(dir, '**')).each do |match|
        publish Pathname.new(match).relative_path_from(pd)
      end
    end
  end
end
