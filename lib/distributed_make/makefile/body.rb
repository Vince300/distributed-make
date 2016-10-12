require "distributed_make/makefile/base"

require "treetop"

module DistributedMake::Makefile
  # Makefile body syntax node.
  #
  # This is the root node of a Makefile syntax tree.
  class Body < Treetop::Runtime::SyntaxNode
    # Returns the AST representation of this syntax node.
    #
    # @return [Array] Array of Makefile rules syntax tree nodes.
    def to_ast
      rule.elements.map { |rule| rule.to_ast }
    end
  end
end
