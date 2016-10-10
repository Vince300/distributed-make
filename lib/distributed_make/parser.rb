require "distributed_make/base"
require "distributed_make/syntax_error"
require "distributed_make/makefile/body"
require "distributed_make/makefile/identifier"
require "distributed_make/makefile/rule"
require "distributed_make/makefile/command"

require "treetop"

module DistributedMake
  module Parser
    # Load the Makefile grammar
    Treetop.load(File.expand_path('../makefile/grammar.treetop', __FILE__))

    # Singleton instance of the Makefile parser
    @@parser = MakefileParser.new

    # Parses the given source as a Makefile
    def self.parse(source, filename=nil)
      # Run the parser
      tree = @@parser.parse(source)

      # Handle errors
      if tree.nil?
        raise SyntaxError.new(@@parser.failure_reason, @@parser.failure_line, @@parser.failure_column, filename)
      end

      # Return AST
      return tree.to_ast
    end
  end
end
