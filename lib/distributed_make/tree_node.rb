require "distributed_make/base"

module DistributedMake
  # Represents a node in a Makefile tree.
  class TreeNode
    # @return [String] name of this node
    attr_reader :name

    # @return [Array(TreeNode)] parents of this node
    attr_reader :parents

    # @return [Array(TreeNode)] children of this node
    attr_reader :children

    # @return [Object] contents of this node
    attr_accessor :content

    # @param [String] name Name of this node
    def initialize(name, content = nil)
      @name = name
      @parents = []
      @children = []
      @content = content
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

    # Add a child to the current node.
    #
    # @param [TreeNode] node Node to add to this node.
    # @return [TreeNode] The added tree node, to allow chaining calls.
    def <<(node)
      @children << node
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
      def append_parent(parent)
        @parents << parent
      end
  end
end
