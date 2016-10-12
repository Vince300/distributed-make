require "distributed_make/base"
require "distributed_make/syntax_error"
require "distributed_make/makefile/body"
require "distributed_make/makefile/identifier"
require "distributed_make/makefile/rule"
require "distributed_make/makefile/command"

require "treetop"

# Makefile source parser module
module DistributedMake::Parser
  # Load the Makefile grammar
  Treetop.load(File.expand_path('../makefile/grammar.treetop', __FILE__))

  # Parses the given source as a Makefile
  #
  # @param [String] source Source code to parse as a Makefile
  # @param [String, nil] filename Name of the file to include in error messages
  # @return [Array] the abstract syntax tree. See the Makefile::Body syntax node for details.
  def self.parse(source, filename=nil)
    # Instantiate the makefile parser
    parser = MakefileParser.new

    # Run the parser
    tree = parser.parse(source)

    # Handle errors
    if tree.nil?
      raise DistributedMake::SyntaxError.new(parser.failure_reason, parser.failure_line, parser.failure_column, filename)
    end

    # Return AST
    return tree.to_ast
  end
end
