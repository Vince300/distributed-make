# Vagrant stage
# Deploys to vagrant managed workers
# Original source: https://gist.github.com/bjjb/7926219
set :stage, :vagrant

set :daemon_user, 'vagrant'

# Run rake vagrant task to get ssh config
raw_ssh_options = `rake vagrant ssh-config`

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

# Declare servers for Capistrano
#
# Server role is based on its identifier (ie. worker# has the worker role)
# Other settings are provided by Vagrant
hosts.each do |name, host|
  server host['HostName'],
    roles: name.sub(/\d+$/, ''),
    user: host['User'],
    port: host['Port'],
    ssh_options: {
      keys: [host['IdentityFile']],
      forward_agent: host['ForwardAgent'] == 'yes'
    }
end
