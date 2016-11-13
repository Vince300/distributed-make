require "distributed_make/base"
require "distributed_make/rule"
require "distributed_make/rule_stub"
require "distributed_make/makefile_error"
require "distributed_make/tree_node"

module DistributedMake
  # Module that implements a converter that builds a tree structure to represent rules and dependencies, based on the
  # abstract syntax tree returned by the {DistributedMake::Parser#parse} method.
  module TreeBuilder
    # Build a tree from the given ast.
    #
    # @param [Array<DistributedMake::Rule>] ast
    # @param [String, nil] wanted_rule top-level rule name to be returned
    # @return [TreeNode, nil] tree node corresponding to the `wanted_rule`, or `nil`
    def self.build_tree(ast, filename=nil, wanted_rule=nil)
      # The list of nodes that have been created to represent the make tree
      defined_nodes = {}

      # Process all rules present in the AST
      ast.each do |rule|
        # Get the defined node for this rule
        node = defined_nodes[rule.name]

        # Create the tree node
        if node.nil?
          node = TreeNode.new(rule)
          defined_nodes[node.name] = node
        else
          # Node already created before
          if node.is_stub?
            node.rulify(rule)
          else
            # The node already is a rule
            raise MakefileError.new(
              "Rule #{rule.name} already defined at line #{node.defined_at}",
              rule.defined_at,
              filename
            )
          end
        end

        # Insert the node into the tree
        # This node is either a root node, or has already been created as a dependency of another node
        # So we just have to create (or add) dependencies from the current tree
        node.dependencies.each do |dependency|
          dep_node = defined_nodes[dependency]

          # Create a new dependency node
          if dep_node.nil?
            dep_node = TreeNode.new(RuleStub.new(dependency))
            defined_nodes[dependency] = dep_node
          end

          # Check that the current node is not an ancestor of dep_node
          # This would indicate a circular dependency in the Makefile
          unless node.is_root?
            if node.parentage.include? dep_node
              # There is a circular dependency, build a proper error message
              parentage = node.parentage
              target_index = parentage.find_index(dep_node)
              parentage = parentage[0..target_index]

              # Raise the error
              raise MakefileError.new("Circular dependency found: #{parentage.join(" -> ")}",
                                      rule.defined_at, filename)
            end
          end

          # Add the dependency node to the current node
          node << dep_node
        end
      end

      if ast.empty?
        return nil
      else
        # Find the wanted rule, or the first one
        wanted_rule = ast.first.name if wanted_rule.nil?
        return defined_nodes[wanted_rule]
      end
    end
  end
end
