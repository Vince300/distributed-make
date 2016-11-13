describe DistributedMake::TreeBuilder do
  def build_tree(ast, filename = nil)
    DistributedMake::TreeBuilder.build_tree(ast.collect { |rule| DistributedMake::Rule.new(rule[:name],
                                                                                           rule[:dependencies],
                                                                                           rule[:commands],
                                                                                           rule[:defined_at]) },
                                            filename)
  end

  it "builds an empty tree" do
    tree = build_tree([])
    expect(tree).to be_nil
  end

  it "builds a tree for a target with no commands nor dependencies" do
    node = build_tree([{name: 'output.o', dependencies: [], commands: [], defined_at: 1}])

    expect(node.name).to eq 'output.o'
    expect(node.dependencies).to eq []
    expect(node.commands).to eq []
    expect(node.defined_at).to eq 1
  end

  it "builds a tree for a target with one dependencies" do
    node = build_tree([{name: 'output.o', dependencies: %W(source.c), commands: [], defined_at: 1}])

    # Root node checking
    expect(node.name).to eq 'output.o'
    expect(node.dependencies).to eq %W(source.c)
    expect(node.commands).to eq []
    expect(node.defined_at).to eq 1

    # Dependency node checking
    expect(node.children.first).not_to be_nil
    node = node.children.first

    expect(node.name).to eq 'source.c'
    expect(node).to be_a DistributedMake::RuleStub
  end

  it "detects duplicated rules" do
    expect do
      build_tree([{name: 'a', dependencies: [], commands: [], defined_at: 1},
                  {name: 'a', dependencies: [], commands: [], defined_at: 2}])
    end.to raise_error(DistributedMake::MakefileError, /already/)
  end

  it "detects direct circular dependencies" do
    expect do
      build_tree([{name: 'a', dependencies: ['b'], commands: [], defined_at: 1},
                  {name: 'b', dependencies: ['a'], commands: [], defined_at: 2}])
    end.to raise_error(DistributedMake::MakefileError, /circular/i)
  end

  it "detects longer circular dependencies" do
    expect do
      build_tree([{name: 'a', dependencies: ['c'], commands: [], defined_at: 1},
                  {name: 'b', dependencies: ['a'], commands: [], defined_at: 2},
                  {name: 'c', dependencies: ['b'], commands: [], defined_at: 3}])
    end.to raise_error(DistributedMake::MakefileError, /circular/i)
  end

  Dir.glob("spec/fixtures/**/Makefile").each do |makefile|
    it "builds a tree for #{makefile}" do
      tree = DistributedMake::Parser.parse(File.read(makefile), makefile)
      expect do
        DistributedMake::TreeBuilder.build_tree(tree, makefile).print_tree do |node, prefix|
          puts "#{prefix} #{(node || node.name).to_s}"
        end
      end.to_not raise_error
    end
  end
end
