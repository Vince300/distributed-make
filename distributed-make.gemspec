# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "distributed_make/version"

Gem::Specification.new do |spec|
  spec.name          = "distributed-make"
  spec.version       = DistributedMake::VERSION
  spec.authors       = DistributedMake::AUTHORS
  spec.email         = DistributedMake::AUTHOR_EMAILS

  spec.summary       = %q{distributed-make distributed systems project}
  spec.homepage      = "https://bitbucket.org/Vince300/distributed-make"
  spec.license       = ""

  spec.required_ruby_version = "2.3.1"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "" # No push URL
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  if Dir.exist? File.expand_path(File.join(__FILE__, '..', '.git'))
    spec.files       = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  else
    spec.files       = Dir.glob('**/*').reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # YARD documentation
  spec.add_development_dependency "yard", "~> 0.9.5"

  # Rake task runner
  spec.add_runtime_dependency 'rake', '~>11.3'

  # SSHKit for remoting
  spec.add_runtime_dependency 'sshkit', '~>1.11'

  # RSpec testing suite
  spec.add_runtime_dependency 'rspec', '~>3.5'

  # Treetop parser engine
  spec.add_runtime_dependency 'treetop', '~>1.6'

  # Command line interface
  spec.add_runtime_dependency 'commander', '~>4.4'
end
