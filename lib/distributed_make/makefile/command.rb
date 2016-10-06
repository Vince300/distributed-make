require "distributed_make/base"

require "treetop"

module DistributedMake::Makefile
  class Command < Treetop::Runtime::SyntaxNode
    def to_ast
      self.text_value
    end
  end
end
