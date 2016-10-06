require "distributed_make/base"

require "treetop"

module DistributedMake::Makefile
  class Body < Treetop::Runtime::SyntaxNode
    def to_ast
      rule.elements.map { |rule| rule.to_ast }
    end
  end
end
