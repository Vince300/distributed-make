require "distributed_make/base"

module DistributedMake
  # Represents a Makefile rule
  #
  # @attr_reader [String] name Name of this rule.
  # @attr_reader [Array] dependencies List of dependencies for this rule.
  # @attr_reader [Array<String>] commands Commands to execute as part of this rule.
  # @attr_reader [Fixnum] defined_at Line at which this rule was defined in the source.
  class Rule
    attr_reader :name, :dependencies, :commands, :defined_at

    # Initializes a new instance of the Rule class from an AST node.
    #
    # @param [Hash] ast_node Syntax node used to define this rule.
    def initialize(ast_node)
      @name = ast_node[:target]
      @dependencies = ast_node[:dependencies]
      @commands = ast_node[:commands]
      @defined_at = ast_node[:defined_at]
    end
  end
end
