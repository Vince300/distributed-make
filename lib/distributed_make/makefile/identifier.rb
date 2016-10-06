require "distributed_make/base"

require "treetop"

module DistributedMake::Makefile
  class Identifier < Treetop::Runtime::SyntaxNode
    def to_ast
      self.text_value
    end
  end
end
