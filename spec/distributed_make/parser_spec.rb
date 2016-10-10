describe DistributedMake::Parser do
  def parse(source, filename = nil)
    DistributedMake::Parser.parse(source, filename)
  end

  it "parses an empty file" do
    tree = parse("")
    expect(tree).to eq [ ]
  end

  it "parses a target with no commands nor dependencies" do
    tree = parse("output.o:")
    expect(tree).to eq [ { target: 'output.o', dependencies: [], commands: [], defined_at: 1 } ]
  end

  it "parses a target with one dependency" do
    tree = parse("output.o: source.c")
    expect(tree).to eq [ { target: 'output.o', dependencies: %W(source.c), commands: [], defined_at: 1 } ]
  end

  it "parses a target with multiple dependencies" do
    tree = parse("output.o: source.c source.h")
    expect(tree).to eq [ { target: 'output.o', dependencies: %W(source.c source.h), commands: [], defined_at: 1 } ]
  end

  it "parses a target without dependencies, but a command" do
    tree = parse("output.o:\n\techo 'Hello, world!' >output.o")
    expect(tree).to eq [ { target: 'output.o', dependencies: [], commands: ["echo 'Hello, world!' >output.o"], defined_at: 1 } ]
  end

  it "parses a target with a dependency, but a command" do
    tree = parse("output.o: source.c\n\techo 'Hello, world!' >output.o")
    expect(tree).to eq [ { target: 'output.o', dependencies: %W(source.c), commands: ["echo 'Hello, world!' >output.o"], defined_at: 1 } ]
  end

  it "parses a target with dependencies, but a command" do
    tree = parse("output.o: source.c source.h\n\techo 'Hello, world!' >output.o")
    expect(tree).to eq [ { target: 'output.o', dependencies: %W(source.c source.h), commands: ["echo 'Hello, world!' >output.o"], defined_at: 1 } ]
  end

  it "does not care about extra whitespace" do
    tree = parse("output.o:source.c source.h\n\t\t\techo 'Hello, world!' >output.o\n\n\n")
    expect(tree).to eq [ { target: 'output.o', dependencies: %W(source.c source.h), commands: ["echo 'Hello, world!' >output.o"], defined_at: 1 } ]
  end

  it "supports leading white lines" do
    tree = parse("      \n\n\noutput.o:")
    expect(tree).to eq [ { target: 'output.o', dependencies: [], commands: [], defined_at: 4 } ]
  end

  it "expects targets to start on a line start" do
    expect { parse("  output.o:") }.to raise_error(DistributedMake::SyntaxError)
  end

  it "expects commands to start with tabs" do
    expect { parse("output.o:\n  echo 'Hello, world!'") }.to raise_error(DistributedMake::SyntaxError)
  end

  it "reads multiple rules" do
    tree = parse(<<-EOT)
program: a.o b.o
\tgcc -o program a.o b.o

a.o: a.c
\tgcc -c a.c

b.o: b.c
\tgcc -c b.c

EOT
    expect(tree).to eq [
      {
        target: 'program',
        dependencies: %W(a.o b.o),
        commands: [ "gcc -o program a.o b.o" ],
        defined_at: 1
      },
      {
        target: 'a.o',
        dependencies: %W(a.c),
        commands: [ "gcc -c a.c" ],
        defined_at: 4
      },
      {
        target: 'b.o',
        dependencies: %W(b.c),
        commands: [ "gcc -c b.c" ],
        defined_at: 7
      }
    ]
  end

  Dir.glob("spec/fixtures/**/Makefile").each do |makefile|
    it "parses #{makefile}" do
      expect { parse(File.read(makefile), makefile) }.to_not raise_error
    end
  end
end
