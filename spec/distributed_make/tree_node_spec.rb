require "rspec/expectations"

RSpec::Matchers.define :match_tree do |expected|
  def node_matches(expected_node, actual_node)
    expected_node[:name] == actual_node.name and
      (expected_node[:content].nil? || expected_node[:content] == actual_node.content) and
      (expected_node[:children].nil? || multinode_matches(expected_node[:children], actual_node.children))
  end

  def multinode_matches(expected_nodes, actual_nodes)
    node_lookup = Hash[expected_nodes.map { |node| [node[:name], node] }]
    actual_lookup = Hash[actual_nodes.map { |node| [node.name, node] }]

    node_lookup.length == actual_lookup.length and node_lookup.all? { |name, expected|
      other = actual_lookup[name]
      not other.nil? and node_matches(expected, other)
    }
  end

  match do |actual|
    result = node_matches(expected, actual)
    unless result
      actual.print_tree do |node, prefix|
        puts "#{prefix} #{node.name}"
      end
    end
    result
  end
end

describe DistributedMake::TreeNode do
  it "describes a single node" do
    node = DistributedMake::TreeNode.new("hello")

    expect(node).to match_tree({name: "hello"})
  end

  it "describes a simple chain" do
    node = DistributedMake::TreeNode.new("root")
    node << DistributedMake::TreeNode.new("hello")

    expect(node).to match_tree({name: "root", children: [{name: "hello"}]})
  end

  it "describes a simple tree" do
    node = DistributedMake::TreeNode.new("root")
    node << DistributedMake::TreeNode.new("a")
    node << DistributedMake::TreeNode.new("b")

    expect(node).to match_tree({
                                 name: "root",
                                 children: [
                                   {
                                     name: "a"
                                   },
                                   {
                                     name: "b"
                                   }
                                 ]
                               })
  end

  it "describes trees with more depth" do
    node = DistributedMake::TreeNode.new("root")
    node << DistributedMake::TreeNode.new("a") << DistributedMake::TreeNode.new("b")

    expect(node).to match_tree({
                                 name: "root",
                                 children: [
                                   {name: "a",
                                    children: [
                                      {
                                        name: "b"
                                      }
                                    ]}
                                 ]
                               })
  end

  it "supports multi-parented nodes" do
    root1 = DistributedMake::TreeNode.new("root1")
    root2 = DistributedMake::TreeNode.new("root2")
    a = DistributedMake::TreeNode.new("a")

    root1 << a
    root2 << a

    expect(root1).to match_tree({
                                  name: "root1",
                                  children: [
                                    {
                                      name: "a"
                                    }
                                  ]
                                })

    expect(root2).to match_tree({
                                  name: "root2",
                                  children: [
                                    {
                                      name: "a"
                                    }
                                  ]
                                })
  end

  it "reports root nodes" do
    root = DistributedMake::TreeNode.new("root")
    child = DistributedMake::TreeNode.new("child")

    root << child

    expect(root.is_root?).to be_truthy
    expect(child.is_root?).to_not be_truthy
  end

  it "reports leaf nodes" do
    root = DistributedMake::TreeNode.new("root")
    child = DistributedMake::TreeNode.new("child")
    leaf = DistributedMake::TreeNode.new("leaf")

    root << child << leaf

    expect(root.is_leaf?).to_not be_truthy
    expect(child.is_leaf?).to_not be_truthy
    expect(leaf.is_leaf?).to be_truthy
  end

  it "allows node access through names" do
    root = DistributedMake::TreeNode.new("root")
    a = DistributedMake::TreeNode.new("a")
    b = DistributedMake::TreeNode.new("b")

    root << a
    root << b

    expect(root["a"]).to eq a
    expect(root["b"]).to eq b
    expect(root["c"]).to be_nil
  end
end
