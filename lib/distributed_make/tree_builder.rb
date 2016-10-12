require "distributed_make/base"
require "distributed_make/rule"
require "distributed_make/makefile_error"

require "tree"

# Module that implements a converter that builds a tree structure to represent rules and dependencies, based on the
# abstract syntax tree returned by the @see DistributedMake::Parser#parse method.
module DistributedMake::TreeBuilder
  # Build a tree from the given ast.
  #
  # @param [Array<DistributedMake::Rule>] ast
  def self.build_tree(ast, filename=nil)
    # The list of nodes that have been created to represent the make tree
    defined_nodes = {}

    # Process all rules present in the AST
    ast.each do |rule|
      # Get the defined node for this rule
      node = defined_nodes[rule.name]

      # Create the tree node
      if node.nil?
        node = Tree::TreeNode.new(rule.name)
        defined_nodes[node.name] = node
      end

      # Build the node contents
      if node.content.nil?
        node.content = rule
      else
        # The node already has a content attribute defined
        # This means this rule has already been defined
        raise DistributedMake::MakefileError.new(
          "Rule #{rule.name} already defined at line #{node.content.defined_at}",
          rule.defined_at,
          filename
        )
      end

      # Insert the node into the tree
      # This node is either a root node, or has already been created as a dependency of another node
      # So we just have to create (or add) dependencies from the current tree
      node.content.dependencies.each do |dependency|
        dep_node = defined_nodes[dependency]

        # Create a new dependency node
        if dep_node.nil?
          dep_node = Tree::TreeNode.new(dependency)
          defined_nodes[dependency] = dep_node
        end

        # Check that the current node is not an ancestor of dep_node
        # This would indicate a circular dependency in the Makefile
        unless dep_node.is_root?
          if dep_node.parentage.include? node
            # There is a circular dependency, build a proper error message
            parentage = dep_node.parentage
            target_index = parentage.find_index(node)
            parentage = parentage[0..target_index]

            # Raise the error
            raise DistributedMake::MakefileError.new("Circular dependency found: #{parentage.join(" -> ")}",
                                                     rule.defined_at, filename)
          end
        end

        # Add the dependency node to the current node
        node << dep_node
      end
    end

    # Return the list of all the root nodes
    defined_nodes.select { |name, node| node.is_root? }.collect { |name, node| node }
  end
end
