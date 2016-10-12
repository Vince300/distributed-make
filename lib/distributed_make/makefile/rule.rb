require "distributed_make/makefile/base"

require "treetop"

module DistributedMake::Makefile
  # Makefile rule syntax node.
  #
  # Represents a rule in a Makefile.
  class Rule < Treetop::Runtime::SyntaxNode
    # Returns the AST representation of this syntax node.
    #
    # @return [Hash] Hash with the following attributes:
    #   * [String] <tt>:target</tt> the target name for this rule.
    #   * [Array<String>] <tt>:dependencies</tt> the list of dependencies for this rule.
    #   * [Array<String>] <tt>:commands</tt> the list of commands to execute as part of this rule.
    #   * [Fixnum] <tt>:defined_at</tt> line in the source file this rule has been declared. Useful for error
    #       reporting.
    def to_ast
      { target: target.to_ast, # Target name
        dependencies: dependencies.elements.map { |el| el.name.to_ast },
        commands: commands.elements.map { |cmd| cmd.command.to_ast },
        defined_at: input.line_of(interval.first) }
    end
  end
end
