describe DistributedMake::TreeBuilder do
  def build_tree(ast, filename = nil)
    DistributedMake::TreeBuilder.build_tree(ast.collect { |rule| DistributedMake::Rule.new(rule[:target],
                                                                                           rule[:dependencies],
                                                                                           rule[:commands],
                                                                                           rule[:defined_at]) },
                                            filename)
  end

  it "builds an empty tree" do
    tree = build_tree([])
    expect(tree).to eq []
  end

  it "builds a tree for a target with no commands nor dependencies" do
    tree = build_tree([{target: 'output.o', dependencies: [], commands: [], defined_at: 1}])

    # Only one root
    expect(tree.length).to eq 1

    node = tree[0]
    expect(node.name).to eq 'output.o'
    expect(node.content.name).to eq 'output.o'
    expect(node.content.dependencies).to eq []
    expect(node.content.commands).to eq []
    expect(node.content.defined_at).to eq 1
  end

  it "builds a tree for a target with one dependencies" do
    tree = build_tree([{target: 'output.o', dependencies: %W(source.c), commands: [], defined_at: 1}])

    # Only one root
    expect(tree.length).to eq 1

    node = tree[0]

    # Root node checking
    expect(node.name).to eq 'output.o'
    expect(node.content.name).to eq 'output.o'
    expect(node.content.dependencies).to eq %W(source.c)
    expect(node.content.commands).to eq []
    expect(node.content.defined_at).to eq 1

    # Dependency node checking
    expect(node['source.c']).not_to be_nil
    node = node['source.c']

    expect(node.name).to eq 'source.c'
    expect(node.content).to be_nil
  end

  it "detects duplicated rules" do
    expect do
      build_tree([{target: 'a', dependencies: [], commands: [], defined_at: 1},
                  {target: 'a', dependencies: [], commands: [], defined_at: 2}])
    end.to raise_error(DistributedMake::MakefileError)
  end

  it "detects direct circular dependencies" do
    expect do
      build_tree([{target: 'a', dependencies: ['b'], commands: [], defined_at: 1},
                  {target: 'b', dependencies: ['a'], commands: [], defined_at: 2}])
    end.to raise_error(DistributedMake::MakefileError)
  end

  it "detects longer circular dependencies" do
    expect do
      build_tree([{target: 'a', dependencies: ['c'], commands: [], defined_at: 1},
                  {target: 'b', dependencies: ['a'], commands: [], defined_at: 2},
                  {target: 'c', dependencies: ['b'], commands: [], defined_at: 3}])
    end.to raise_error(DistributedMake::MakefileError)
  end

  Dir.glob("spec/fixtures/**/Makefile").each do |makefile|
    it "builds a tree for #{makefile}" do
      tree = DistributedMake::Parser.parse(File.read(makefile), makefile)
      expect { DistributedMake::TreeBuilder.build_tree(tree, makefile) }.to_not raise_error
    end
  end
end
