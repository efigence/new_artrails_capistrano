# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'capistrano/new_artrails_capistrano/version'

Gem::Specification.new do |spec|
  spec.name          = 'new_artrails_capistrano'
  spec.version       = Capistrano::NewArtrailsCapistrano::VERSION
  spec.authors       = ['Marcin Kalita', 'Rafał Lisowski']
  spec.email         = ['rubyconvict@gmail.com', 'lisukorin@gmail.com']

  spec.summary       = 'Capistrano 3 deployment using Rsync, a local Git repository and sudo as user.'
  spec.description   = 'This gem is a viable alternative to Git deployments ' \
    'on production machines. Commands are run under a different user than the `deploy` user.'
  spec.homepage      = 'https://github.com/efigence/new_artrails_capistrano'
  spec.license       = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise RuntimeError.new, 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         =
    # bundle exec manifest save # based on `git ls-files -z`.split("\x0") and more (works only on staged files)
    File.read('Manifest.txt').split("\n").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '~> 2.1.1'

  spec.add_dependency 'capistrano', '>= 3.5', '< 4'
  spec.add_dependency 'capistrano-rails', '>= 1.3', '< 2'
  spec.add_dependency 'capistrano-rvm', '>= 0.1', '< 2'

  # turnout dependency, rack requires Ruby version >= 2.2.2
  spec.add_dependency 'rack', '>= 1.6', '< 2'
  spec.add_dependency 'turnout', '>=  2.2', '< 3'

  # http://yehudakatz.com/2010/12/16/clarifying-the-roles-of-the-gemspec-and-gemfile/
  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'fuubar', '~> 2'

  # `activesupport` requires Ruby version >= 2.2.2
  spec.add_development_dependency 'activesupport', '~> 4.2.9'
  spec.add_development_dependency 'github_changelog_generator', '~> 1'

  # `listen` requires Ruby version >= 2.2
  spec.add_development_dependency 'listen', '~> 3.0.8'

  spec.add_development_dependency 'guard', '~> 2'
  spec.add_development_dependency 'guard-bundler', '~> 2'
  spec.add_development_dependency 'guard-reek', '~> 1'
  spec.add_development_dependency 'guard-rspec', '~> 4'
  spec.add_development_dependency 'guard-rubocop', '~> 1'
  spec.add_development_dependency 'rubocop', '~> 0.48.1'
  # rubocop + rubocop-rspec used by text editor from specific rvm ruby
  # gem uninstall rubocop && gem install rubocop -v='0.39'
  # https://github.com/backus/rubocop-rspec/issues/153
  spec.add_development_dependency 'rubocop-rspec', '~> 1'
  spec.add_development_dependency 'rubygems-manifest', '~> 0'
  spec.add_development_dependency 'coveralls', '0.8.19'
  spec.add_development_dependency 'simplecov', '0.12.0'
  spec.add_development_dependency 'simplecov-console', '~> 0'
  spec.add_development_dependency 'codeclimate-test-reporter', '0.4.8'
  spec.add_development_dependency 'pry', '~> 0.10.4'
end
