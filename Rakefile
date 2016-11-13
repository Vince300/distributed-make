require 'yaml'
require 'sshkit'
require 'sshkit/dsl'
include SSHKit::DSL

# In a development environment, load RSpec and set it as the default task
begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)

  # Declare the test task to run the spec tests
  task test: :spec

  # Set the test task as the default
  task default: :test
rescue LoadError
end

# Method to fetch Vagrant hosts from the currently running machines
def vagrant_hosts
  # Run rake vagrant task to get ssh config
  nullarg = if ENV['OS'] == 'Windows_NT'
              "2>NUL"
            else
              "2>/dev/null"
            end
  raw_ssh_options = `cd machines && vagrant ssh-config #{nullarg}`

  hosts = Hash.new { |h, k| h[k] = {} }
  current_host = nil

  # Parse options into the hosts hash
  raw_ssh_options.split("\n").select { |x| not x.empty? }.map(&:strip).each do |l|
    k, v = l.split(/\s/, 2).map(&:strip)

    if k == "Host"
      current_host = v
    else
      hosts[current_host][k] = v
    end
  end

  return hosts.collect do |name, host|
    SSHKit::Host.new(hostname: host['HostName'],
                     user: host['User'],
                     port: host['Port'],
                     ssh_options: {
                       keys: [host['IdentityFile']],
                       forward_agent: host['ForwardAgent'] == 'yes'
                     })
  end
end

# Load the current environment config
$env = ENV['RAKE_ENV'] || 'vagrant'
config_file = File.join('config', $env + '.yml')
$config = if File.exist? config_file
           YAML.load(File.read(config_file))
         else
           {}
         end

# Derive the deployment settings from the config
def release_path
  $config['release_path']
end

def current_path
  File.join(release_path, 'current')
end

def shared_path
  File.join(release_path, 'shared')
end

def bundler_path
  File.join(release_path, 'bundle')
end

def workers
  $config['workers']
end

def hosts
  if $env == 'vagrant'
    vagrant_hosts
  else
    fail "custom hosts not yet supported"
  end
end

# Load custom tasks from `lib/rake/tasks`
Dir.glob("lib/rake/tasks/*.rake").each { |r| import r }
