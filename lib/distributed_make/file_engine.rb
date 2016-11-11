require "distributed_make/base"
require "distributed_make/utils/simple_renewer"

require "thread"
require "socket"
require "resolv"

module DistributedMake
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
      return file if available? file

      loop do
        # Find the file on the pool
        target_tuple = begin
          ts.read([:file, file, host, nil], 0)
        rescue Rinda::RequestExpiredError
          ts.read([:file, file, nil, nil])
        end

        # Connect to the host dispatch
        remote_host = target_tuple[2]
        remote_port = target_tuple[3]
        tries = 0

        s = begin
          TCPSocket.new(remote_host, remote_port)
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
          logger.info("connected to dispatch server #{remote_host}:#{remote_port}")
        end

        # Send the request
        Marshal.dump([:remote, file], s)

        # Wait for the response
        response = Marshal.load(s)

        if response.is_a? Array
          case response[0]
            when :connect
              logger.info("downloading #{file} from #{remote_host}")

              # Connect to file serving port
              fs = TCPSocket.new(remote_host, response[1])

              # Download everything from socket to local file
              File.open(File.join(dir, file), "wb") do |output|
                IO.copy_stream(fs, output)
              end

              # Close socket
              fs.close

              logger.info("completed download of #{file} from #{remote_host}")
            when :error
              fail "failed to get file from #{remote_host}: #{response[1]}"
          end
        else
          fail "unexpected response from dispatch server"
        end

        # We are done, close the dispatch socket
        s.close

        return file
      end
    end

    # Starts the file engine
    # @return [void]
    def start
      @run_dispatcher = true

      # Start the dispatcher TCP socket
      dispatcher_server = TCPServer.new(host, 0)
      logger.info("file server running on #{host}:#{dispatcher_server.addr[1]}")

      # Now we have a port, publish all files on the tuple space using the renewer
      publish_all

      # Start the thread that accepts connections for the server
      @dispatcher_thread = Thread.start(dispatcher_server, &method(:dispatcher_callback))
      return
    end

    # Stops the file engine
    # @return [void]
    def stop
      @run_dispatcher = false
      @dispatcher_thread.join
      @dispatcher_thread = nil
      logger.debug("stopped file dispatcher")
      return
    end

    def publish(file)
      unless @published_files[file]
        logger.debug("publishing #{file}")
        @published_files[file] = true
        ts.write([:file, file, host, @dispatcher_server.addr[1]], Utils::SimpleRenewer.new(period))
      end
    end

    protected
    def publish_all
      pd = Pathname.new(dir)
      Dir.glob(File.join(dir, '**')).each do |match|
        publish Pathname.new(match).relative_path_from(pd)
      end
    end

    def dispatcher_callback(dispatcher_server)
      # Start accepting clients
      while @run_dispatcher do
        begin
          # Start a thread handling the client data
          Thread.start(dispatcher_server.accept_nonblock, &method(:client_callback))
        rescue IO::EWOULDBLOCKWaitReadable, IO::WaitReadable, Errno::EINTR
          # 0.5s timeout means we will at most wait 500ms to exit the dispatcher
          # when FileEngine#stop is called
          IO.select([dispatcher_server], [], [], 0.5)
          retry if @run_dispatcher
        end
      end

      logger.debug("stopping file server")

      # Terminate the server
      dispatcher_server.close
    end

    def client_callback(client)
      caddr = "#{client.peeraddr[1]}:#{client.peeraddr[2]}"
      logger.info("accepted client from #{caddr}")
      loop do
        begin
          # Load incoming message
          mesg = Marshal.load(client)

          # Handle message
          if mesg.is_a? Array
            case mesg[0]
              when :remote
                logger.info("#{caddr} requested #{mesg[1]}")

                # Launch a new TCP server
                srv = TCPServer.new(host, 0)

                # Send out server port
                Marshal.dump([:connect, srv.addr[1]], client)

                # Wait for the file to be served
                serve_callback(srv.accept, mesg[1])

                # Close the server
                srv.close

                # Stop dispatching to this client
                break
              else
                logger.warn("unsupported message #{mesg[0]} from #{caddr}")
            end
          else
            # Abort on dubious clients
            logger.error("unexpected message #{mesg} from #{caddr}")
            break
          end
        rescue StandardError => e
          logger.error("error receiving message from #{caddr}: #{e}")
          break
        end
      end

      client.close
    end

    def serve_callback(sock, file)
      File.open(File.join(dir, file), "rb") do |input|
        IO.copy_stream(input, sock)
      end

      sock.close
    end
  end
end
