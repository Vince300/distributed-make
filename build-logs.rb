require 'logger'
require 'fileutils'


logger = Logger.new(STDOUT)

# Prepare log directory
FileUtils.rmtree('log') if Dir.exist? 'log'
Dir.mkdir('log')

# Deploy
system("RAKE_ENV=grid5000-119 rake deploy")

# Stop daemons
system("RAKE_ENV=grid5000-119 rake daemon:stop")

env_files = Dir.glob("config/grid5000-*.yml").sort
env_files.reverse! if ARGV.include? "--reverse"

# For each possible setup
env_files.each do |f|
  # Environment name
  env = File.basename(f, '.yml')

  logger.info("Current environment: #{env}")
  # Cleanup examples
  `RAKE_ENV=#{env} rake examples:clean`

  Dir.glob("spec/fixtures/*").each do |folder|
    # Store logs
    sample = File.basename(folder)
    logger.info("Current example: #{sample}")
    log_file = File.expand_path("log/#{env}-#{sample}.log")
    Dir.chdir(folder) do
      pid = Process.spawn("bundle exec distributed-make --unsafe >#{log_file}")
      # Sleep for 0.5s
      sleep(0.5)
      # Start daemons
      `RAKE_ENV=#{env} rake daemon:start`
      # Wait
      Process.wait pid
    end
    # Stop daemons
    `RAKE_ENV=#{env} rake daemon:stop`
  end
end

# Stop daemons
system("RAKE_ENV=grid5000-119 rake daemon:stop")

# Tar the logs
system("tar cJf $(date '+%y-%m-%d-%H-%M-%S').tar.bz2 log")
FileUtils.rmtree('log')
