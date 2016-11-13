require "distributed_make/rule_stub"

module DistributedMake
  # Represents a Makefile rule
  class Rule < RuleStub
    # @return [Array] list of dependencies for this rule
    attr_reader :dependencies

    # @return [Array<String>] commands to execute as part of this rule
    attr_reader :commands

    # @return [Fixnum] line at which this rule was defined in the source
    attr_reader :defined_at

    # @param [String, Rule, RuleStub] target the target name for this rule, or a {RuleStub} derivative to initialize
    # @param [Array<String>] dependencies the list of dependencies for this rule.
    # @param [Array<String>] commands the list of commands to execute as part of this rule.
    # @param [Fixnum] defined_at line in the source file this rule has been declared. Useful for error reporting.
    def initialize(target, dependencies = nil, commands = nil, defined_at = nil)
      if target.is_a? RuleStub
        super(target.name)
        @is_stub = true

        rulify(target) if target.is_a? Rule
      else
        super(target)
        @dependencies = dependencies
        @commands = commands
        @defined_at = defined_at
      end
    end

    # If this rule represents a rule stub (is_stub? is true), then upgrade it
    # using the rule provided as a parameter
    #
    # @param [Rule] rule Rule whose parameters will be cloned
    # @return [Rule] the rule itself
    def rulify(rule)
      fail "This rule is not a stub, it cannot be rulified" unless is_stub?
      fail "Given rule is not a rule" unless rule.is_a? Rule
      fail "Rule names do not match" unless name == rule.name

      @dependencies = rule.dependencies
      @commands = rule.commands
      @defined_at = rule.defined_at
      @is_stub = false

      return self
    end

    # @return [Boolean] `true` if this rule does not produce any output
    def phony?
      if @commands
        @commands.empty?
      else
        false
      end
    end

    # Converts this rule into a hash for inspection.
    #
    # @return [Hash] A hash representing the object with the following attributes:
    #   * [String] <tt>:name</tt> the target name for this rule.
    #   * [Array<String>] <tt>:dependencies</tt> the list of dependencies for this rule.
    #   * [Array<String>] <tt>:commands</tt> the list of commands to execute as part of this rule.
    #   * [Fixnum] <tt>:defined_at</tt> line in the source file this rule has been declared. Useful for error
    #       reporting.
    def to_h
      {
        :name => @name,
        :dependencies => @dependencies,
        :commands => @commands,
        :defined_at => @defined_at
      }
    end

    # Return a value indicating if this rule is a stub
    #
    # @return [Bool] <tt>true</tt> if this rule is a stub, <tt>false</tt> otherwise.
    def is_stub?
      !!@is_stub
    end

    # Returns a string representing this Makefile rule.
    #
    # @return [String] String representing the rule.
    def to_s
      if is_stub?
        super
      else
        "(rule) #{@name}: #{@dependencies.join(' ')} " +
          "(done: #{
          if done? then
            'yes'
          else
            'no'
          end}, processing: #{
          if processing? then
            'yes'
          else
            'no'
          end})"
      end
    end
  end
end
