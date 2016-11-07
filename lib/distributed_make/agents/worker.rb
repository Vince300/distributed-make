require "distributed_make/base"
require "distributed_make/agents/agent"
require "distributed_make/utils/simple_renewer"
require "distributed_make/utils/multilog"

require "drb/drb"
require "rinda/ring"

require "tmpdir"

module DistributedMake
  module Agents
    # Represents a distributed make system worker.
    class Worker < Agent
      # Initialize a new worker agent
      #
      # @param [String] name Name of the worker
      # @param [Logger] logger Logger instance for reporting status
      def initialize(name, logger)
        $LOGGER_NAME = name
        super(Utils::Multilog.new(logger))
        self.logger.debug("worker #{name} initialized")
      end

      # Run the worker agent on the given host.
      #
      # @param [String, nil] host hostname for the dRuby service
      # @yieldparam [Worker] agent running driver agent
      # @return [void]
      def run(host = nil)
        logger.debug("begin #{__method__.to_s}")

        # Start DRb service
        start_drb(host)

        # true if we should continue running the worker
        run_worker = true
        # true if we already have informed the user we are looking for a tuple space
        printed_waiting = false

        while run_worker
          begin
            # Reset the Multilog so it only points to the default logger
            logger.reset

            # Locate tuple space
            join_tuple_space(Rinda::RingFinger.finger.lookup_ring_any)
            logger.info("located tuple space #{ts}")

            # Reset printed_waiting for future reconnect
            printed_waiting = false

            # Read the parameters for this space
            logger.debug("new tuple space period is #{service(:job).period} second(s)")

            # Register the new logger
            logger.add_logger(service(:log).logger)
            logger.info("joined the worker pool")

            # Create the temporary working directory
            Dir.mktmpdir("distributed-make") do |tmpdir|
              # Change to this directory so tools behave as expected
              Dir.chdir(tmpdir) do
                # Setup the tmp dir as an instance variable
                @working_dir = tmpdir
                logger.debug("working directory: #{@working_dir}")

                # We have joined the tuple space, start processing using this agent
                yield self
              end
            end
          rescue Interrupt => e
            # Just exit, Ctrl+C
            run_worker = false
          rescue DRb::DRbConnError => e
            logger.info("tuple space terminated, waiting for new tuple space to join")
          rescue RuntimeError => e
            if e.message == 'RingNotFound'
              # The Ring was not found, notify the user (once) about retrying
              unless printed_waiting
                logger.warn("checking periodically if tuple space is available")
                printed_waiting = true
              end
            else
              # Log unexpected exception
              logger.fatal(e)

              # Abort because of runtime error
              run_worker = false
            end
          end
        end

        logger.debug("end #{__method__.to_s}")
        return
      end

      # Starts an infinite loop to process incoming work on the tuple space.
      #
      # @return [void]
      def process_work
        # Forever
        while true
          # Take a task to do
          tuple = ts.take([:task, nil, :todo])
          rule_name = tuple[1]

          # Notify
          logger.info("got task #{rule_name}")

          # Tell tuple space we are processing, watching for timeout
          ts.write([:task, rule_name, :working], Utils::SimpleRenewer.new(2 * service(:job).period))

          # Find what we have to do
          commands = service(:rule).commands(rule_name) || []
          logger.info("commands to run: #{commands.join("\n")}")

          unless service(:job).dry_run?
            # Do some work
            sleep(1.0)
          end

          # Log that we are done
          logger.info("task #{rule_name} completed")

          # We are done here
          ts.write([:task, rule_name, :done])
          ts.take([:task, rule_name, :working])
        end
        return
      end
    end
  end
end
