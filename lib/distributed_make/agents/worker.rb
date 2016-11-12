require "distributed_make/base"
require "distributed_make/agents/agent"
require "distributed_make/utils/simple_renewer"
require "distributed_make/utils/multilog"

require "drb/drb"
require "rinda/ring"

require "tmpdir"

require "eventmachine"

module DistributedMake
  module Agents
    # Represents a distributed make system worker.
    class Worker < Agent
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
      def run(host = nil, &block)
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
                logger.debug("working directory: #{tmpdir}")

                # We have joined the tuple space, start processing using this agent
                go(service(:job).period, &block)
              end
            end

            logger.reset
            logger.info("tuple space terminated, waiting for new tuple space to join")
          rescue Interrupt => e
            # Just exit, Ctrl+C
            run_worker = false
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

        begin
          # Exit smoothly
          DRb.stop_service
        rescue Interrupt => e
        end
        logger.debug("end #{__method__.to_s}")
        return
      end

      # Starts an infinite loop to process incoming work on the tuple space.
      #
      # @return [void]
      def process_work
        # Forever
        EventMachine::Iterator.new(proc { }, 1).each do |prc, iter|
          # Once the task processing completed, proceed to get the next task
          EventMachine.defer(method(:take_tuple), proc do |tuple|
            if tuple
              process_task(tuple) do
                iter.next
              end
            else
              # No tuple to process, driver process left
              EventMachine.stop
              iter.next
            end
          end)
        end
        return
      end

      protected
      def take_tuple
        begin
          # Take a task to do
          ts.take([:task, nil, :todo])
        rescue DRb::DRbConnError => e
          return nil
        end
      end

      def process_task(tuple)
        rule_name = tuple[1]

        # Notify
        logger.info("got task #{rule_name}")

        # Tell tuple space we are processing, watching for timeout
        ts.write([:task, rule_name, :working], Utils::SimpleRenewer.new(service(:job).period))

        # Fetch all dependencies
        # TODO: Configurable concurrency
        EventMachine::Iterator.new(service(:rule).dependencies(rule_name), 4).each(proc do |dep, iter|
          file_engine.get(dep).callback do
            iter.next
          end
        end, proc do
          # Find what we have to do
          commands = service(:rule).commands(rule_name)

          # Status of executed commands
          failed = false

          unless service(:job).dry_run?
            # Do the work
            commands.each do |command|
              logger.info("run: #{command}")
              output = `#{command} 2>&1` # execute verbatim command, redirect stderr

              # Log command return code
              suffix = unless output.empty? then
                         ": "
                       else
                         ""
                       end
              if $?.success?
                logger.info("success#{suffix}")
              else
                logger.error("failure (#{$?})#{suffix}")
                failed = true
              end

              unless output.empty?
                # Log command output
                logger.info(output)
              end

              break if failed
            end
          else
            commands.each do |command|
              logger.info("dry-run: #{command}")
            end
          end

          unless failed
            # Log that we are done
            logger.info("task #{rule_name} completed")

            # Handle rules that do not generate anything
            done_flag = :done
            unless file_engine.available? rule_name
              done_flag = :phony
            else
              # Publish the output file
              file_engine.publish(rule_name)
            end

            # We are done here
            ts.write([:task, rule_name, done_flag])
          else
            # Log that we failed
            logger.info("task #{rule_name} failed")

            # We failed
            ts.write([:task, rule_name, :failed])
          end

          # Remove working task tuple
          ts.take([:task, rule_name, :working])

          # We can now continue
          yield
        end)
      end
    end
  end
end
