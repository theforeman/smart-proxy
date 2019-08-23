group :test do
  gem 'mocha', '> 0.13.0', :require => false
  gem 'single_test'
  gem 'ci_reporter', '>= 1.6.3', "< 2.0.0", :require => false
  gem 'test-unit'
  gem 'public_suffix', '< 3' if RUBY_VERSION < '2.1'
  gem 'benchmark-ips'
  gem 'ruby-prof'
  gem 'rubocop', '~> 0.50.0'

  if RUBY_VERSION < '2.2.2'
    gem 'rack-test', '~> 0.7.0'
  else
    gem 'rack-test'
  end

  if RUBY_VERSION < '2.2'
    gem 'rdoc', '< 6'
    gem 'parallel', '< 1.14' # rubocop dependency
  else
    gem 'rdoc'
  end

  gem 'rake'
  gem 'rubocop-checkstyle_formatter', '~> 0.2'
  gem 'webmock'

  # Technically this is a hard dependency of the facts module but that's only
  # used in discovery. This at least allows us to run the tests on it
  gem 'facter', :require => false
end
