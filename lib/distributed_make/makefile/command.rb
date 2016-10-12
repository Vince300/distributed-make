require "distributed_make/makefile/base"

require "treetop"

module DistributedMake::Makefile
  # Makefile command syntax node.
  #
  # Represents a command line that is part of a Makefile rule.
  class Command < Treetop::Runtime::SyntaxNode
    # Returns the AST representation of this syntax node.
    #
    # @return [String] String containing the command to run as part of the rule.
    def to_ast
      self.text_value
    end
  end
end
