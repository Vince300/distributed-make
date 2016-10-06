desc "Run RSpec on the server"
task :rspec do
  on roles(:all) do
    within release_path do
      execute :bundle, 'exec', 'rspec', '--format', 'progress'
    end
  end
end

before :rspec, 'rvm:hook'
