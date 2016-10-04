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