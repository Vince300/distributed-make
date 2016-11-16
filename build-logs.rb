require 'logger'
require 'fileutils'


logger = Logger.new(STDOUT)

# Prepare log directory
FileUtils.rmtree('log') if Dir.exist? 'log'
Dir.mkdir('log')

# For each possible setup
Dir.glob("config/grid5000-*.yml").each do |f|
  # Environment name
  env = File.basename(f, '.yml')

  logger.info("Current environment: #{env}")
  # Cleanup examples
  `RAKE_ENV=#{env} rake examples:clean`

  Dir.glob("spec/fixtures/*").each do |folder|
    # Start daemons
    `RAKE_ENV=#{env} rake daemon:start`
    # Store logs
    sample = File.basename(folder)
    logger.info("Current example: #{sample}")
    log_file = File.expand_path("log/#{env}-#{sample}.log")
    Dir.chdir(folder) do
      system("bundle exec distributed-make >#{log_file}")
    end
    # Stop daemons
    `RAKE_ENV=#{env} rake daemon:stop`
  end
end

# Tar the logs
system("tar cJf $(date '+%y-%m-%d-%H-%M-%S').tar.bz2 log")
FileUtils.rmtree('log')
