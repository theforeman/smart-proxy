group :test do
  gem 'mocha', '~> 1.10', :require => false
  gem 'ci_reporter', '>= 1.6.3', "< 2.0.0", :require => false
  gem 'test-unit'
  gem 'benchmark-ips'
  gem 'ruby-prof', '< 1.4'
  gem 'rubocop', '~> 0.80.0'
  gem 'rubocop-performance', '~> 1.5.2'
  gem 'rack-test'
  gem 'rdoc'
  gem 'rake'
  gem 'rubocop-checkstyle_formatter', '~> 0.2'
  gem 'webmock'

  # Technically this is a hard dependency of the facts module but that's only
  # used in discovery. This at least allows us to run the tests on it
  gem 'facter', :require => false
end
