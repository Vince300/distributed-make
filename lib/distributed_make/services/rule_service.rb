require "distributed_make/base"

module DistributedMake::Services
  # A service that holds information about commands to run for the defined targets
  class RuleService
    # Get the commands for the given rule.
    #
    # @param [String] rule_name name of the rule
    # @return [Hash<String, Array<String>>]
    def commands(rule_name)
      unless @commands.has_key? rule_name
        raise "rule #{rule_name} does not exist"
      end

      @commands[rule_name]
    end

    # Get the dependencies for the given rule.
    #
    # @param [String] rule_name name of the rule, or nil to access all the rules
    # @return [Array<String>, Hash<String, Array<String>>]
    def dependencies(rule_name = nil)
      if rule_name
        unless @dependencies.has_key? rule_name
          raise "rule #{rule_name} does not exist"
        end

        @dependencies[rule_name]
      else
        @dependencies
      end
    end

    # @param [Hash<String, [Array<String>]>] commands hash of command definitions
    # @param [Hash<String, [Array<String>]>] dependencies hash of dependency definitions
    def initialize(commands, dependencies)
      @commands = commands
      @dependencies = dependencies
    end
  end
end
