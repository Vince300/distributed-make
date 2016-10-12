require "distributed_make/makefile/base"

require "treetop"

module DistributedMake::Makefile
  # Makefile identifier syntax node.
  #
  # Represents an identifier in a Makefile. This can be a filename or a rule name.
  class Identifier < Treetop::Runtime::SyntaxNode
    # Returns the AST representation of this syntax node.
    #
    # @return [String] String containing the name of this identifier.
    def to_ast
      self.text_value
    end
  end
end
