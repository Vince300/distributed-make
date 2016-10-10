require "distributed_make/base"

module DistributedMake
  class Rule
    attr_accessor :name, :dependencies, :commands, :defined_at

    def initialize(ast_node)
      @name = ast_node[:target]
      @dependencies = ast_node[:dependencies]
      @commands = ast_node[:commands]
      @defined_at = ast_node[:defined_at]
    end
  end
end
