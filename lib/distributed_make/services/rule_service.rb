require "distributed_make/base"

module DistributedMake::Services
  # A service that holds information about commands to run for the defined targets
  class RuleService
    # Initialize a new instance of the RuleService class.
    #
    # @param [Hash<String, [Array<String>, nil]>] commands hash of command definitions (or nil for stubs)
    def initialize(commands)
      @commands = commands
    end

    # Get the commands for the given rule.
    #
    # @param [String] rule_name name of the rule
    def commands(rule_name)
      unless @commands.has_key? rule_name
        raise "rule #{rule_name} does not exist"
      end

      @commands[rule_name]
    end
  end
end
