require 'logger'
require 'fileutils'
require 'tempfile'

logger = Logger.new(STDOUT)

# Prepare log directory
FileUtils.rmtree('log') if Dir.exist? 'log'
Dir.mkdir('log')

# Deploy and start
system("RAKE_ENV=grid5000-119 rake deploy daemon:stop daemon:start")

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
    log_file = File.expand_path("log/#{env}-#{sample}.log")

    unless File.exist? log_file
      logger.info("Current example: #{sample}")
      workers = env.sub('grid5000-', '').to_i

      Dir.chdir(folder) do
        Tempfile.open do |file|
          system("bundle exec distributed-make --workers #{workers} >#{file.path}")
          FileUtils.cp(file.path, log_file)
        end
      end
    end
  end
end

# Tar the logs
system("tar czvf $(date '+%y-%m-%d-%H-%M-%S').tar.gz log")
FileUtils.rmtree('log')
