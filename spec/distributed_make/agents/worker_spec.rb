describe DistributedMake::Agents::Worker do
  before :all do
    # A logger for agent testing
    @logger = Logger.new(STDERR)

    # A driver so the worker can connect to it
    @driver = DistributedMake::Agents::Driver.new(@logger)

    # Mutex and condition variable for the driver process exit
    @mtx = Mutex.new
    @ecv = ConditionVariable.new

    @thread = Thread.new do
      @driver.run("localhost", "spec_job", true, 0.1) do
        @mtx.synchronize do
          # Wait for exit
          @ecv.wait(@mtx)
        end
      end
    end
  end

  before :each do
    # The worker to test on
    @worker = DistributedMake::Agents::Worker.new("worker", @logger)
  end

  after :all do
    # Exit the driver thread
    @mtx.synchronize do
      @ecv.signal
    end

    # Wait for the thread to exit
    @thread.join
  end

  it "exits on Ctrl+C" do
    @worker.run("localhost") do
      raise Interrupt.new
    end
  end

  it "uses a temporary directory" do
    @worker.run("localhost") do
      expect(Dir.pwd).to match(/[Tt]e?mp/)

      # exit
      raise Interrupt.new
    end
  end
end
