# config valid only for current version of Capistrano
lock '3.6.1'

set :application, 'distributed-make'
set :repo_url, 'git@bitbucket.org:Vince300/distributed-make.git'

# Deploy to ~/distributed-make for the default non-privileged user
set :deploy_to, '~/distributed-make'

# Copy from local repository
set :scm, :localcopy
set :tar_verbose, false

# Vagrant directory not needed in production
set :include_dir, %W(.rspec .git .gitignore)
set :exclude_dir, %W(vagrant bin config log Gemfile.lock)

# Fix Bundler from different platforms (remove --deployment from default flags)
set :bundle_flags, '--quiet'

# Install test environment to test everything works fine in production
set :bundle_without, 'development'
