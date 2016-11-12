require "distributed_make/base"
require "distributed_make/file_engine"

require "uri"
require "drb/drb"

module DistributedMake::Agents
  # File serving management agent
  class FileServer
    attr_reader :file_engine

    def self.run
      DistributedMake::Agents::FileServer.new.init
    end

    def start(host, dir, logger, period)
      @file_engine = DistributedMake::FileEngine.new(host, dir, logger, period)
      @file_engine.start
    end

    def stop
      @file_engine.stop
      DRb.stop_service
    end

    def init
      # Start the dRuby service serving the file agent
      DRb.start_service("druby://localhost:0", self)
      # Output URI so the parent process can connect
      puts DRb.uri
      STDOUT.flush
      # Wait for termination
      DRb.thread.join
    end
  end
end
