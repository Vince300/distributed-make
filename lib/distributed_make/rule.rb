require "distributed_make/base"
require "distributed_make/rule_stub"

module DistributedMake
  # Represents a Makefile rule
  #
  # @attr_reader [Array] dependencies List of dependencies for this rule.
  # @attr_reader [Array<String>] commands Commands to execute as part of this rule.
  # @attr_reader [Fixnum] defined_at Line at which this rule was defined in the source.
  class Rule < RuleStub
    attr_reader :dependencies, :commands, :defined_at

    # Initializes a new instance of the Rule class.
    #
    # @param [String] target the target name for this rule.
    # @param [Array<String>] dependencies the list of dependencies for this rule.
    # @param [Array<String>] commands the list of commands to execute as part of this rule.
    # @param [Fixnum] defined_at line in the source file this rule has been declared. Useful for error reporting.
    def initialize(target, dependencies, commands, defined_at)
      super(target)
      @dependencies = dependencies
      @commands = commands
      @defined_at = defined_at
    end

    # Converts this rule into a hash for inspection.
    #
    # @return [Hash] A hash representing the object with the following attributes:
    #   * [String] <tt>:target</tt> the target name for this rule.
    #   * [Array<String>] <tt>:dependencies</tt> the list of dependencies for this rule.
    #   * [Array<String>] <tt>:commands</tt> the list of commands to execute as part of this rule.
    #   * [Fixnum] <tt>:defined_at</tt> line in the source file this rule has been declared. Useful for error
    #       reporting.
    def to_h
      {
        :target => @name,
        :dependencies => @dependencies.dup,
        :commands => @commands.dup,
        :defined_at => @defined_at
      }
    end

    # Return a value indicating if this rule is a stub
    #
    # @return [Bool] <tt>true</tt> if this rule is a stub, <tt>false</tt> otherwise.
    def is_stub?
      false
    end

    # Returns a string representing this Makefile rule.
    #
    # @return [String] String representing the rule.
    def to_s
      "(rule) #{@name}: #{@dependencies.join(' ')} " +
        "(done: #{if done? then 'yes' else 'no' end}, processing: #{if processing? then 'yes' else 'no' end})"
    end
  end
end
