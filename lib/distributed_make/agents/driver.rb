require "distributed_make/base"
require "distributed_make/agents/agent"
require "distributed_make/services/job_service"
require "distributed_make/services/log_service"
require "distributed_make/services/rule_service"
require "distributed_make/source_error"

require "drb/drb"
require "rinda/tuplespace"
require "rinda/ring"
require "ipaddr"

module DistributedMake
  module Agents
    # Represents a distributed make system driver.
    class Driver < Agent
      # @param [Logger] logger Logger instance for reporting status
      def initialize(logger)
        $LOGGER_NAME = "driver"
        # So Multilog handles adding the name
        super(Utils::Multilog.new(logger))
        self.logger.debug("driver initialized")
      end

      # Run the driver agent on the given host.
      #
      # @param [String, nil] host hostname for the dRuby service
      # @param [String] job_name name of the job to report
      # @param [Bool] dry_run `true` to enable dry-run
      # @param [Fixnum] period period of the main tuple space
      # @yieldparam [Driver] agent running driver agent
      def run(host = nil, job_name = nil, dry_run = false, period = 5, &block)
        logger.debug("begin #{__method__.to_s}")

        # Start DRb service
        start_drb(host)

        # Create the tuple space to be shared
        join_tuple_space(Rinda::TupleSpace.new(period))

        # Register the job service
        register_service(:job, Services::JobService.new(job_name, dry_run, period))

        # Register the log service (use the Logger instance, not the Multilog)
        register_service(:log, Services::LogService.new(logger.loggers.first))

        # Compute Ring server addresses
        # Default: bind to 0.0.0.0
        addresses = [Socket::INADDR_ANY]

        # Check if the specified host should be used as broadcast
        begin
          addresses = [IPAddr.new(host).to_s]
        rescue IPAddr::Error
          # Not a valid IP address, probably a hostname such as localhost
        end

        # Setup Ring server
        @server = Rinda::RingServer.new(ts, addresses)
        logger.info("started ring server")

        begin
          # Now the agent is ready, delegate functionnality to block
          go_block(period, &block)
        rescue Interrupt => e
          logger.info("exiting")
        end

        logger.debug("end #{__method__.to_s}")
      end

      # Starts the build process for the given Makefile tree.
      # This methods only returns on completion or on a fatal error.
      #
      # @param [TreeNode] tree make tree returned by the {TreeBuilder#build_tree} method
      # @return [void]
      def make_tree(tree)
        # Build the make tree lookup
        @task_tree = tree
        @task_dict = build_tree_lookup(tree)

        # Reset the start time
        @started_at = nil

        # Check that all required files are present in the source directory
        check_stubs(tree)

        # Register the rule service
        non_stubs = @task_dict.select { |key, node| not node.content.is_stub? }.to_a
        commands = non_stubs.collect { |key, node| [key, node.content.commands] }.to_h
        dependencies = non_stubs.collect { |key, node| [key, node.content.dependencies] }.to_h
        register_service(:rule, Services::RuleService.new(commands, dependencies))

        # Create the notifier that detects task events
        done_notifier = ts.notify(nil, [:task, nil, nil])

        # Add all nodes that are not done
        append_not_done(tree)

        # Wait for task notifications
        handle_events(done_notifier)
        return
      end

      protected
      # Start an event loop to handle events from the given notifier. The given notifier is expected to listen for
      # events on tuples that start with a symbol which identify the tuple type, for instance `:task` to represent a
      # task.
      #
      # This method will call the corresponding `on_type_event` method, where `type` is the tuple type, and `event` is
      # the raised event.
      #
      # This method returns when the notifier is cancelled.
      #
      # @param [Rinda::NotifyTemplateEntry] notifier notifier to listen from
      # @return [void]
      def handle_events(notifier)
        notifier.each do |event, tuple|
          begin
            if event == 'close' then
              logger.debug("stopped listening for #{notifier[1][0]} events")
            else
              handler = ('on_' + tuple[0].to_s + '_' + event).to_sym
              if respond_to?(handler, true) # Only call if handler is defined
                if send(handler, tuple, notifier) == :exit
                  # Fast exit from notifier loop
                  break
                end
              else
                logger.warn("unhandled #{handler} event")
              end
            end
          rescue StandardError => e
            # Unexpected error while processing event
            logger.fatal(e)
            raise e
          end
        end
        return
      end

      # Task tuple write event handler.
      #
      # @param [Array<Symbol, String, Symbol>] tuple task tuple
      # @param [Rinda::NotifyTemplateEntry] notifier notifier which is the source for this event
      def on_task_write(tuple, notifier)
        if [:done, :phony].include? tuple[2]
          # A task is completed
          ts.take([:task, tuple[1], tuple[2]])

          # If the task is done, fetch the produced file using the engine
          if tuple[2] == :done
            file_engine.get(tuple[1]).callback do
              # This task is now done
              node = @task_dict[tuple[1]]
              rule_done(node.content)

              # Walk parents of this node to process further rules
              node.parents.each do |parent|
                unless parent.content.processing? or parent.content.done?
                  # The parent task is not being processed
                  if parent.children.all? { |child| child.content.done? }
                    # All children of this parent are done, process parent
                    logger.debug("task #{parent.content.name} is ready to be processed")
                    add_rule(parent.content)
                  end
                end
              end

              # Root rule completed?
              if @task_tree.content.done?
                logger.info("build job completed in #{Time.now - @started_at}s")
                notifier.cancel
              end
            end
          else
            fail ":phony not yet supported!"
          end
        elsif tuple[2] == :failed
          # A task failed running because an external command returned non-zero
          ts.take([:task, tuple[1], :failed])

          # We should abort right now: canel the notifier and remove all tasks
          logger.error("task #{tuple[1]} failed, aborting further compilation")
          notifier.cancel
          return :exit
        elsif tuple[2] == :working
          # A task is being worked on
          logger.info("task #{tuple[1]} is being processed")

          # Remove the :scheduled task
          ts.take([:task, tuple[1], :scheduled])
        end
        return nil
      end

      # Task tuple delete event handler.
      #
      # @param [Array<Symbol, String, Symbol>] tuple task tuple
      # @param [Rinda::NotifyTemplateEntry] notifier notifier which is the source for this event
      def on_task_delete(tuple, notifier)
        # Some task became outdated, suspicious
        if tuple[2] == :working
          # A worker just died, add the task back
          logger.warn("worker died processing #{tuple[1]}, restoring")

          # Restore task
          ts.write([:task, tuple[1], :todo])
        elsif tuple[2] == :scheduled
          # A worker didn't report processing the task
          logger.error("worker didn't start working on scheduled task #{tuple[1]}, restoring")

          # Restore task
          ts.write([:task, tuple[1], :todo])
        end
      end

      # Task tuple take event handler.
      #
      # @param [Array<Symbol, String, Symbol>] tuple task tuple
      # @param [Rinda::NotifyTemplateEntry] notifier notifier which is the source for this event
      def on_task_take(tuple, notifier)
        if tuple[2] == :todo
          # Some worker requested a task to be done
          # If the worker goes away before pushing the :working task, this unit will be lost
          logger.debug("task #{tuple[1]} has been scheduled")

          # Add a tuple that explains this
          # Its expire should be short, so just set it to a few periods
          ts.write([:task, tuple[1], :scheduled], 5 * service(:job).period)

          # Note that the first task being scheduled indicates a worker joined the space, so start timing now
          @started_at = Time.now unless @started_at
        end
      end

      # Build a lookup hash from a make tree.
      #
      # @param [TreeNode] tree make tree
      # @return [Hash(String, TreeNode)] lookup hash
      def build_tree_lookup(tree)
        result = {}
        tree.each_node do |node|
          result[node.name] = node
        end
        return result
      end

      # Add task entries ready for processing to the tuple space
      #
      # @param [TreeNode] tree make tree
      # @return [void]
      def append_not_done(tree)
        tree.each_node do |node|
          rule = node.content

          unless rule.done? or rule.processing?
            # Check all child nodes are ready
            if node.children.all? { |child| child.content.done? }
              add_rule(node.content)
            end
          end

          not rule.done?
        end
        return
      end

      # Check that source dependencies are present in the source directory
      #
      # @param [TreeNode] tree make tree
      # @return [void]
      def check_stubs(tree)
        tree.each_node do |node|
          rule = node.content

          if rule.is_stub?
            # This rule is a pure dependency, it must be available in the current working directory
            unless file_engine.available? rule.name
              raise SourceError.new(rule.name)
            end
          end

          true # continue enumerating child nodes
        end
        return
      end

      # Add a rule as a task in the tuple space.
      #
      # @param [Rule] rule make rule to add
      # @return [Rule] added rule
      def add_rule(rule)
        logger.debug("adding #{rule} to be done")
        rule.processing = true
        ts.write([:task, rule.name, :todo])
        rule
      end

      # Flags a rule as done after processing.
      #
      # @param [Rule] rule make rule to flag as done
      # @return [Rule] rule flagged as done
      def rule_done(rule)
        rule.done = true
        rule.processing = false
        logger.info("task #{rule.name} is completed")
        rule
      end
    end
  end
end
