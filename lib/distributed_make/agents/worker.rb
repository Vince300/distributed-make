require "distributed_make/base"
require "distributed_make/agents/agent"
require "distributed_make/utils/simple_renewer"
require "distributed_make/utils/multilog"

require "drb/drb"
require "rinda/ring"

require "priority_queue"

require "tmpdir"
require "open3"

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
                with_file_engine(service(:job).period, true) do
                  # We have joined the tuple space, start processing using this agent
                  yield self
                end
              end
            end
          rescue Interrupt => e
            # Just exit, Ctrl+C
            run_worker = false
          rescue DRb::DRbConnError => e
            logger.reset
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

        stop_drb
        logger.debug("end #{__method__.to_s}")
        return
      end

      # Starts an infinite loop to process incoming work on the tuple space.
      #
      # @return [void]
      def process_work
        with_rule_queue do
          # Forever
          loop do
            attempt = 0

            # Find out best option using priority queue
            # Note that we use "to_a" so the dep_thread doesn't modify
            # the priority queue while we are enumerating it
            rq = @rule_queue.to_a
            tuple = nil
            rq.each do |target, priority|
              if priority < service(:rule).dependencies(target).length
                begin
                  tuple = ts.take([:task, target, :todo], 0)
                  break
                rescue Rinda::RequestExpiredError
                  attempt = attempt + 1
                end
              end
            end

            # We couldn't get a task, wait for one
            unless tuple
              tuple = ts.take([:task, nil, :todo])
              logger.info("got last-chance task #{tuple[1]}")
            else
              logger.info("got #{attempt}/#{rq.length} task #{tuple[1]}")
            end

            # The obtained rule name
            rule_name = tuple[1]

            unless unsafe?
              # Tell tuple space we are processing, watching for timeout
              working_tuple = [:task, rule_name, :working]
              with_renewer(ts.write(working_tuple, service(:job).period)) do
                process_rule(rule_name)

                # Remove working task tuple
                ts.take(working_tuple)
              end
            else
              # Process directly
              process_rule(rule_name)
            end
          end
        end
        return
      end

      private

      # Process the given rule
      #
      # @param [String] rule_name Name of the rule to process
      def process_rule(rule_name)
        # Fetch all dependencies
        service(:rule).dependencies(rule_name).each do |dep|
          file_engine.get(dep)

          # Update priority of corresponding tasks
          update_file_rule_dependencies(dep)
        end

        # Find what we have to do
        commands = service(:rule).commands(rule_name)

        # Status of executed commands
        failed = false

        unless service(:job).dry_run?
          failed = !run_rule_commands(commands, rule_name)
        else
          commands.each do |command|
            logger.info("dry-run: #{command}")
          end
        end

        unless failed
          # Log that we are done
          logger.info("task #{rule_name} completed")

          # Publish the output file
          file_engine.publish(rule_name)

          # Update priority of corresponding tasks
          update_file_rule_dependencies(rule_name)

          # We are done here
          ts.write([:task, rule_name, :done])
        else
          # Log that we failed
          logger.info("task #{rule_name} failed")

          # We failed
          ts.write([:task, rule_name, :failed])
        end
      end

      # Executes the given block while maintaining the rule queue updated with the latest
      # changes and rule events.
      #
      # @return [void]
      def with_rule_queue
        # The dependencies hash, to be modified for each done task
        rule_dependencies = service(:rule).dependencies

        # Inverse dependency hash: which files concern which rules
        @file_dependencies = {}
        rule_dependencies.each do |rule, deps|
          deps.each do |file|
            @file_dependencies[file] = [] unless @file_dependencies[file]
            @file_dependencies[file] << rule
          end
        end

        # Build the initial priority queue
        @rule_queue = PriorityQueue.new
        rule_dependencies.each do |rule, deps|
          @rule_queue.push(rule, deps.length)
        end

        # Notifier and associated thread to remove done tasks
        notifier = ts.notify('write', [:task, nil, :done])
        dep_thread = Thread.start do
          notifier.each do |event, tuple|
            @rule_queue.delete(tuple[1])
          end
        end

        # Remove all already done tasks
        ts.read_all([:task, nil, :done]).each do |t|
          @rule_queue.delete t[1]
        end

        begin
          yield
        ensure
          # Terminate notifier
          notifier.cancel
          dep_thread.join
        end
        return
      end

      # Executes the commands of the current rule
      #
      # @param [Array<String>] commands List of commands to execute
      # @param [String] rule_name Name of the rule being computed
      # @return [Boolean] true if the command succeeded
      def run_rule_commands(commands, rule_name)
        failed = false
        commands.each do |command|
          logger.info("run: #{command}")

          # execute verbatim command, redirect stderr
          Open3.popen2e(command) do |input, pipe, t|
            output = ''

            loop do
              begin
                output += pipe.read_nonblock(80)
              rescue IO::WaitReadable
                IO.select([pipe])
                retry
              rescue EOFError
                break
              end
            end

            # Wait for process completion
            exit_status = t.value

            # Log command return code
            suffix = unless output.empty? then
                       ": #{output}"
                     else
                       ""
                     end
            if exit_status.success?
              logger.info("success#{suffix}")
            else
              logger.error("failure (#{$?})#{suffix}")
              failed = true
            end
          end

          break if failed
        end

        # Ensure the commands produced an output file
        unless failed
          unless file_engine.available? rule_name
            logger.error("no output file produced for #{rule_name}")
            failed = true
          end
        end

        !failed
      end

      # Updates the task priority queue by considering the given file
      # became available.
      #
      # @param [String] file Name of the file that became available
      # @return [void]
      def update_file_rule_dependencies(file)
        if deps = @file_dependencies[file]
          deps.each do |rule|
            if priority = @rule_queue[rule]
              @rule_queue.change_priority(rule, priority - 1)
            end
          end
        end
        return
      end
    end
  end
end
