require "distributed_make/base"
require "distributed_make/agents/agent"

require "drb/drb"
require "rinda/ring"

module DistributedMake::Agents
  # Represents a distributed make system worker.
  class Worker < Agent
    # Run the driver agent on the given host.
    #
    # @param [String, nil] host Hostname for the dRuby service.
    # @yieldparam [Worker] agent Running driver agent.
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
          # Locate tuple space
          @ts = Rinda::RingFinger.finger.lookup_ring_any
          logger.info("located tuple space #{@ts}")

          # Reset printed_waiting for future reconnect
          printed_waiting = false

          # Read the parameters for this space
          tuple = @ts.read([:tuplespace, :period, nil])
          @period = tuple[2]
          logger.debug("new tuple space period is #{@period} second(s)")

          # We have joined the tuple space, start processing using this agent
          yield self
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
    end

    def process_work
      # Forever
      while true
        # Take a task to do
        tuple = @ts.take([:task, nil, :todo])

        # Notify
        logger.info("got task #{tuple[1]}")

        # Tell tuple space we are processing, watching for timeout
        @ts.write([:task, tuple[1], :working], SimpleRenewer.new(2 * @period))

        # Do some work
        sleep(1)

        # Log that we are done
        logger.info("task #{tuple[1]} completed")

        # We are done here
        @ts.write([:task, tuple[1], :done])
        @ts.take([:task, tuple[1], :working])
      end
    end
  end

  class SimpleRenewer
    include DRbUndumped
    def initialize(sec)
      @sec = sec
    end
    def renew
      @sec
    end
  end
end
