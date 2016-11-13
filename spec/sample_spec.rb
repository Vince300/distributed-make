require "fileutils"
require "tmpdir"

describe "sample Makefiles" do
  # Get the path to the distributed-make
  exe_path = File.expand_path(File.join(__FILE__, '..', '..', 'exe', 'distributed-make'))

  Dir.glob("spec/fixtures/*").each do |folder|
    next if folder.match /recurse|2\.59/

    it File.basename(folder) do
      Dir.mktmpdir do |tmp|
        # Copy the base directory
        FileUtils.cp_r File.join(File.expand_path(folder), '.'), tmp, verbose: true

        # Change
        Dir.chdir(tmp) do
          system(RbConfig.ruby, exe_path, "driver", "--host", "10.20.1.1")
        end
      end
    end
  end
end