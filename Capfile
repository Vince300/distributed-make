# Load DSL and set up stages
require "capistrano/setup"

# Include default deployment tasks
require "capistrano/deploy"

# RVM support on server
require "capistrano/rvm"

# Run bundler when deploying
require "capistrano/bundler"

# Deploy via copy from local repository
require "capistrano/localcopy"

# Load custom tasks from `lib/capistrano/tasks` if you have any defined
Dir.glob("lib/capistrano/tasks/*.rake").each { |r| import r }
