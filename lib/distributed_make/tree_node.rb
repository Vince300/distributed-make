require "distributed_make/rule"

module DistributedMake
  # Represents a node in a Makefile tree.
  class TreeNode < Rule
    # @return [Array(TreeNode)] parents of this node
    attr_reader :parents

    # @return [Array(TreeNode)] children of this node
    attr_reader :children

    # @param [Rule, RuleStub] rule rule this node is representing
    def initialize(rule)
      super(rule)
      @parents = []
      @children = []
    end

    # @return [Boolean] `true` if all the dependencies of this rule are done
    def ready?
      children.all? { |rule| rule.done? }
    end

    # Warning: this method should only be used once the tree will not be changed anymore, as the result of this method
    # is cached.
    #
    # @return [Array(TreeNode)] list of transitive dependencies of this node
    def all_dependencies
      # a stub does not have dependencies
      return [] if is_stub?

      # return cached dependencies
      return @all_dependencies if @all_dependencies

      @all_dependencies = []
      children.each do |child|
        # Add the direct dependency
        @all_dependencies << child

        # Add all transitive dependencies for this child
        @all_dependencies.concat(child.all_dependencies)
      end

      # The graph may contain multiple references to the same dependency
      @all_dependencies.uniq!

      return @all_dependencies
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

    # Traverses the tree in breadth order, starting with the leaf-most nodes
    #
    # @yieldparam [TreeNode] node current node
    # @return [void]
    def leaf_traversal(&block)
      traversal_sets = []

      # Current root
      current_set = [self]
      while not current_set.empty?
        traversal_sets << current_set
        current_set = current_set.collect { |node| node.children }.flatten
      end

      traversal_sets.reverse_each do |set|
        set.each(&block)
      end
      return
    end

    protected
      def append_parent(parent)
        @parents << parent
      end
  end
end
