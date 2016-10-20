require "distributed_make/base"

module DistributedMake
  # Represents a node in a Makefile tree.
  #
  # @attr_reader [String] name Name of this node.
  # @attr_reader [Array(TreeNode)] parents Parents of this node.
  # @attr_reader [Array(TreeNode)] children Children of this node.
  # @attr_accessor [Object] content Contents of this node.
  class TreeNode
    attr_reader :name
    attr_accessor :content

    # Create a new tree node.
    #
    # @param [String] name Name of this node
    def initialize(name, content = nil)
      @name = name
      @parents = []
      @children = []
      @children_lookup = {}
      @content = content
    end

    def parents
      @parents.dup
    end

    def children
      @children.dup
    end

    # Get the list of all ancestors for this node
    #
    # @return [Array] Array of all the ancestors of this node.
    def parentage
      # Parentage is the set of parents
      result = @parents.dup

      # With all their respective parents
      @parents.each do |parent|
        result.concat(parent.parentage)
      end

      return result
    end

    # Remove this node from all of its parents
    #
    # @return [TreeNode] The node itself.
    def remove
      # Remove this node in all of its parents
      @parents.each do |parent|
        parent.delete_child(self)
      end

      # Clear parents array
      @parents.clear

      return self
    end

    # Get a value indicating if this node is a leaf.
    #
    # @return [Bool] <tt>true</tt> if this node is a leaf node, <tt>false</tt> otherwise.
    def is_leaf?
      @children.empty?
    end

    # Get a value indicating if this node is a root.
    #
    # @return [Bool] <tt>true</tt> if this node is a root node, <tt>false</tt> otherwise.
    def is_root?
      @parents.empty?
    end

    # Fetch the child with the given name.
    #
    # @param [String] child_name Name of the child to search for.
    # @return [TreeNode, nil] The node with the given name, or <tt>nil</tt> otherwise.
    def [](child_name)
      @children_lookup[child_name]
    end

    # Add a child to the current node.
    #
    # @param [TreeNode] node Node to add to this node.
    # @return [TreeNode] The added tree node, to allow chaining calls.
    def <<(node)
      @children << node
      @children_lookup[node.name] = node
      node.append_parent(self)

      # Allow chaining
      return node
    end

    # Walks the tree starting at this node for pretty-printing the node contents
    #
    # @param [Fixnum] level Current indentation level.
    # @yieldparam [TreeNode] node Current node being printed.
    # @yieldparam [String] prefix Computed prefix to append before printing the node.
    def print_tree(level = 0)
      prefix = ''

      if is_root?
        prefix << '*'
      else
        prefix << '|'
        prefix << (' ' * (level - 1) * 2)
        prefix << '|-'
        prefix << (is_leaf? ? '>' : '+')
      end

      yield self, prefix

      @children.each do |child|
        child.print_tree(level + 1) do |node, prefix|
          yield(node, prefix)
        end
      end
    end

    # Pre-ordered node walking. If the block returns truthy, then sub-nodes are walked.
    #
    # @yieldparam [TreeNode] node The current node.
    def each_node
      if yield self
        @children.each do |child|
          # Call each_node on every child
          child.each_node do |node|
            # Call parent block
            yield node
          end
        end
      end
    end

    protected
      def delete_child(child)
        @children.delete(child)
        @children_lookup.delete(child.name)
      end

      def append_parent(parent)
        @parents << parent
      end
  end
end
