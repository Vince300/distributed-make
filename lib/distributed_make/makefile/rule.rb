require "distributed_make/makefile/base"
require "distributed_make/rule"

require "treetop"

module DistributedMake::Makefile
  # Makefile rule syntax node.
  #
  # Represents a rule in a Makefile.
  class Rule < Treetop::Runtime::SyntaxNode
    # Returns the AST representation of this syntax node.
    #
    # @return [DistributedMake::Rule] Rule class instance that represents the defined rule.
    def to_ast
      DistributedMake::Rule.new(target.to_ast,
                                dependencies.elements.map { |el| el.name.to_ast },
                                commands.elements.map { |cmd| cmd.command.to_ast },
                                input.line_of(interval.first))
    end
  end
end
