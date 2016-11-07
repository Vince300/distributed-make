namespace :daemon do
  desc "Starts the worker daemon"
  task :start do
    on roles(:worker) do
      within current_path do
        execute :mkdir, '-p', File.join(shared_path, 'pids')
        execute :mkdir, '-p', File.join(shared_path, 'log')
        fetch(:workers).each do |worker|
          execute '/sbin/start-stop-daemon', '--pidfile', File.join(shared_path, 'pids', "#{worker}.pid"),
                  '--start', '--make-pidfile', '--chdir', current_path, '--user', fetch(:daemon_user), '--background',
                  '--startas', '/bin/bash', '--', '-c "exec /usr/local/rvm/bin/rvm default do bundle exec distributed-make worker --log ' +
                    File.join(shared_path, 'log', "#{worker}.log") + ' --name "' + worker + '"' + ' 2>&1"'
        end
      end
    end
  end

  desc "Restarts the worker daemon"
  task :restart do
    %w(daemon:stop daemon:start).each do |task|
      Rake::Task[task].invoke
    end
  end

  desc "Stops the worker daemon"
  task :stop do
    on roles(:worker) do
      within current_path do
        fetch(:workers).each do |worker|
          begin
            execute '/sbin/start-stop-daemon', '--stop', '--pidfile', File.join(shared_path, 'pids', "#{worker}.pid")
          ensure
            execute :rm, '-f', File.join(shared_path, 'pids', "#{worker}.pid")
          end
        end
      end
    end
  end
end
