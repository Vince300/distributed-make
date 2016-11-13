desc "Deploys the code to the currently running Vagrant boxes"
task :deploy do |task, args|
  on hosts do
    execute :mkdir, "-p", release_path
    within release_path do
      # Clear the current release path
      execute :rm, "-rf", current_path
      execute :mkdir, "-p", current_path

      # Upload project files
      %w{exe lib distributed-make.gemspec Gemfile Rakefile}.each do |target|
        dir = File.dirname(target)
        execute :mkdir, "-p", dir unless dir == '.'
        upload! target, File.join(current_path, target), recursive: true
      end
    end

    execute :mkdir, "-p", bundler_path
    execute :ln, "-s", bundler_path, File.join(current_path, ".bundle") 

    within current_path do
      # Bundle install
      execute "/usr/local/rvm/bin/rvm", "default", "do", "bundle", "install",
              "--without", "development", "--quiet"
    end
  end
end

namespace :deploy do
  desc "Cleans the target directory"
  task :clean do |task, args|
    on hosts do
      execute :rm, "-rf", release_path
    end
  end
end
