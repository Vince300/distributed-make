# Docker stage
set :stage, :docker

set :daemon_user, 'docker'
set :workers, ['worker']

server '172.17.0.2',
    roles: %W(worker),
    user: 'docker',
    password: 'docker'
