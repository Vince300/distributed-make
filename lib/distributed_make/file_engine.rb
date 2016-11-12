require "distributed_make/base"
require "distributed_make/utils/simple_renewer"

require "thread"
require "socket"
require "resolv"
require "eventmachine"

module DistributedMake
  class FileDeferrable
    include EventMachine::Deferrable

    attr_reader :file

    def initialize(file)
      @file = file
    end

    def self.immediate(file)
      df = FileDeferrable.new(file)
      df.succeed
      return df
    end
  end

  class FileEngineConnection < EventMachine::Connection
    attr_reader :file_engine

    def initialize(file_engine)
      @file_engine = file_engine
    end

    def host
      file_engine.host
    end

    def logger
      file_engine.logger
    end

    def dir
      file_engine.dir
    end

    def peeraddr
      port, ip = Socket.unpack_sockaddr_in(get_peername)
      "#{ip}:#{port}"
    end

    def remote_host
      port, ip = Socket.unpack_sockaddr_in(get_peername)
      ip
    end

    def self.server_port(server)
      sockname = EventMachine.get_sockname(server)
      Socket.unpack_sockaddr_in(sockname)[0]
    end
  end

  class FileDownloadClient < FileEngineConnection
    attr_accessor :file, :deferrable

    def initialize(file_engine, file, deferrable)
      super(file_engine)
      @file = file
      @deferrable = deferrable
    end

    def post_init
      @file = File.open(File.join(dir, file), "wb")
    end

    def receive_data(data)
      @file.write(data)
    end

    def unbind
      @file.close
      logger.info("completed download of #{file} from #{remote_host}")
      deferrable.succeed
    end
  end

  class FileDispatcherClient < FileEngineConnection
    include EventMachine::Protocols::ObjectProtocol
    attr_accessor :file, :deferrable

    def initialize(file_engine, file, deferrable)
      super(file_engine)
      @file = file
      @deferrable = deferrable
    end

    def post_init
      # We are connected, request the file
      send_object([:remote, file])
    end

    def receive_object(response)
      if response.is_a? Array
        case response[0]
          when :connect
            logger.info("downloading #{file} from #{peeraddr}")

            # Connect to file serving port
            EventMachine.connect(remote_host, response[1], FileDownloadClient, file_engine, file, deferrable)

            # Done here
            close_connection
          when :error
            fail "failed to get file from #{remote_host}: #{response[1]}"
        end
      else
        fail "unexpected response from dispatch server"
      end
    end
  end

  class FileDownloadServer < FileEngineConnection
    attr_accessor :file

    def initialize(file_engine, file)
      super(file_engine)
      @file = file
    end

    def post_init
      # As soon as the connection has been opened, serve the file
      streamer = EventMachine::FileStreamer.new(self, File.join(dir, file))
      streamer.callback do
        close_connection_after_writing
      end
    end
  end

  class FileDispatcherServer < FileEngineConnection
    include EventMachine::Protocols::ObjectProtocol

    def post_init
      logger.info("accepted client from #{peeraddr}")
    end

    def receive_object(mesg)
      if mesg.is_a? Array
        case mesg[0]
          when :remote
            logger.info("#{peeraddr} requested #{mesg[1]}")

            # Setup the server
            server = EventMachine.start_server(host, 0, FileDownloadServer, file_engine, mesg[1])
            port = server_port(server)

            # Send the port info back
            send_object([:connect, port])

            # We are done serving this user
            close_connection_after_writing
          else
            logger.warn("unsupported message #{mesg[0]} from #{peeraddr}")
        end
      else
        # Abort on dubious clients
        logger.error("unexpected message #{mesg} from #{peeraddr}")
        close_connection
      end
    end
  end

  class FileEngine
    # @return [String] Hostname of the current engine
    attr_accessor :host

    # @return [Rinda::TupleSpace] Tuple space to support file sharing
    attr_accessor :ts

    # @return [String] Absolute path to the working directory managed by this instance
    attr_accessor :dir

    # @return [Logger] Logger to report events to
    attr_accessor :logger

    # @return [Integer] Tuple space period
    attr_accessor :period

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
      return FileDeferrable.immediate(file) if available? file

      # The deferrable object to wait for the incoming file
      df = FileDeferrable.new(file)

      # Find where the file is available
      target_tuple = begin
        ts.read([:file, file, host, nil], 0)
      rescue Rinda::RequestExpiredError
        ts.read([:file, file, nil, nil])
      end

      # Connect to the host dispatch
      remote_host = target_tuple[2]
      remote_port = target_tuple[3]

      # Connect to the dispatcher, status will be reported later on df
      EventMachine.connect(remote_host, remote_port, FileDispatcherClient, self, file, df)

      return df
    end

    # Starts the file engine
    # @return [void]
    def start
      # Initialize the server
      @server = EventMachine.start_server(host, 0, FileDispatcherServer, self)
      @dispatcher_port = FileEngineConnection.server_port(@server)
      logger.info("file server running on #{host}:#{@dispatcher_port}")

      # Now we have a port, publish all files on the tuple space using the renewer
      publish_all

      return
    end

    # Stops the file engine
    # @return [void]
    def stop
      EventMachine.stop_server(@server)
      @dispatcher_port = nil
      @server = nil
      logger.debug("stopped file dispatcher")
      return
    end

    def publish(file)
      unless @published_files[file]
        logger.debug("publishing #{file}")
        @published_files[file] = true
        ts.write([:file, file, host, @dispatcher_port], Utils::SimpleRenewer.new(period))
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
