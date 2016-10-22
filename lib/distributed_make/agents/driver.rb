require "distributed_make/base"
require "distributed_make/agents/agent"
require "distributed_make/services/job_service"
require "distributed_make/services/rule_service"

require "drb/drb"
require "rinda/tuplespace"
require "rinda/ring"
require "ipaddr"

module DistributedMake
  module Agents
    # Represents a distributed make system driver.
    class Driver < Agent
      # Run the driver agent on the given host.
      #
      # @param [String, nil] host hostname for the dRuby service
      # @param [String] job_name name of the job to report
      # @param [Bool] dry_run `true` to enable dry-run
      # @param [Fixnum] period period of the main tuple space
      # @yieldparam [Driver] agent running driver agent
      def run(host = nil, job_name = nil, dry_run = false, period = 5)
        logger.debug("begin #{__method__.to_s}")

        # Start DRb service
        start_drb(host)

        # Create the tuple space to be shared
        join_tuple_space(Rinda::TupleSpace.new(period))

        # Register the job service
        register_service(:job, Services::JobService.new(job_name, dry_run, period))

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
          yield self
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

        # Register the rule service
        commands = @task_dict.collect { |key, node| [key, node.content.commands] }.to_h
        register_service(:rule, Services::RuleService.new(commands))

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
                send(handler, tuple, notifier)
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
        if tuple[2] == :done
          # A task is completed
          ts.take([:task, tuple[1], :done])

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
        elsif tuple[2] == :working
          # A task is being worked on
          logger.info("task #{tuple[1]} is being processed")

          # Remove the :scheduled task
          ts.take([:task, tuple[1], :scheduled])
        end
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
