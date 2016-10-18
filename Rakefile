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

desc "Runs vagrant from the vagrant directory"
task :vagrant do |task, args|
  ARGV.shift
  Dir.chdir 'vagrant' do
    sh "vagrant", *ARGV
  end

  # https://stackoverflow.com/questions/3586997/how-to-pass-multiple-parameters-to-rake-task
  #
  # By default, rake considers each 'argument' to be the name of an actual task. 
  # It will try to invoke each one as a task.  By dynamically defining a dummy
  # task for every argument, we can prevent an exception from being thrown
  # when rake inevitably doesn't find a defined task with that name.
  ARGV.each do |arg|
    task arg.to_sym do ; end
  end
end
