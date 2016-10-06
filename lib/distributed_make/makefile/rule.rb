require "distributed_make/base"

require "treetop"

module DistributedMake::Makefile
  class Rule < Treetop::Runtime::SyntaxNode
    def to_ast
      { target: target.to_ast, # Target name
        dependencies: dependencies.elements.map { |el| el.name.to_ast },
        commands: commands.elements.map { |cmd| cmd.command.to_ast } }
    end
  end
end
