require "distributed_make/base"
require "distributed_make/agents/agent"

require "drb/drb"
require "rinda/tuplespace"
require "rinda/ring"
require "ipaddr"

module DistributedMake::Agents
  # Represents a distributed make system driver.
  class Driver < Agent
    # Run the driver agent on the given host.
    #
    # @param [String, nil] host Hostname for the dRuby service.
    # @param [Fixnum] period Period of the main tuple space.
    # @yieldparam [Driver] agent Running driver agent.
    def run(host = nil, period = 5)
      logger.debug("begin #{__method__.to_s}")

      # Start DRb service
      start_drb(host)

      # Create the tuple space to be shared
      @ts = Rinda::TupleSpace.new(period)
      @period = period

      # Set the properties as a tuple
      @ts.write([:tuplespace, :period, @period])

      # Compute Ring server addresses
      # Default: bind to 0.0.0.0
      addresses = [Socket::INADDR_ANY]

      # Check if the specified host should be used as broadcast
      begin
        addresses = [IPAddr.new(host).to_s]
      rescue AddressFamilyError
        # Not a valid IP address, probably a hostname such as localhost
      end

      # Setup Ring server
      @server = Rinda::RingServer.new(@ts, addresses)
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
    # @param [Array(TreeNode)] tree Make tree returned by the TreeBuilder.
    def make_tree(tree)
      # Build the make tree lookup
      task_dict = build_tree_lookup(tree)

      # Create the notifier that detects task events
      done_notifier = @ts.notify(nil, [:task, nil, nil])

      # Add all nodes that are not done
      append_not_done(tree)

      # Wait for task notifications
      done_notifier.each do |event, tuple|
        begin
          if event == 'write'
            if tuple[2] == :done
              # A task is completed
              @ts.take([:task, tuple[1], :done])

              # This task is now done
              node = task_dict[tuple[1]]
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

              # Are all root nodes completed?
              if tree.all? { |node| node.content.done? }
                done_notifier.cancel
              end
            elsif tuple[2] == :working
              # A task is being worked on
              logger.info("task #{tuple[1]} is being processed")

              # Remove the :scheduled task
              @ts.take([:task, tuple[1], :scheduled])
            end
          elsif event == 'delete'
            # Some task became outdated, suspicious
            if tuple[2] == :working
              # A worker just died, add the task back
              logger.warn("worker died processing #{tuple[1]}, restoring")

              # Restore task
              @ts.write([:task, tuple[1], :todo])
            elsif tuple[2] == :scheduled
              # A worker didn't report processing the task
              logger.error("worker didn't start working on scheduled task #{tuple[1]}, restoring")

              # Restore task
              @ts.write([:task, tuple[1], :todo])
            end
          elsif event == 'take'
            if tuple[2] == :todo
              # Some worker requested a task to be done
              # If the worker goes away before pushing the :working task, this unit will be lost
              logger.debug("task #{tuple[1]} has been scheduled")

              # Add a tuple that explains this
              # Its expire should be short, so just set it to a few periods
              @ts.write([:task, tuple[1], :scheduled], 5 * @period)
            end
          end
        rescue StandardError => e
          # Unexpected error while processing event
          logger.fatal(e)
          raise e
        end
      end
    end

    private
    def build_tree_lookup(tree)
      result = {}
      tree.each do |root|
        root.each_node do |node|
          result[node.name] = node
        end
      end
      return result
    end

    def append_not_done(tree)
      tree.each do |root|
        root.each_node do |node|
          rule = node.content

          unless rule.done?
            # Check all child nodes are ready
            if node.children.all? { |child| child.content.done? }
              add_rule(node.content)
            end
          end

          not rule.done?
        end
      end
    end

    def add_rule(rule)
      logger.debug("adding #{rule.name} to be done")
      rule.processing = true
      @ts.write([:task, rule.name, :todo])
    end

    def rule_done(rule)
      rule.done = true
      rule.processing = false
      logger.info("task #{rule.name} is completed")
    end
  end
end
