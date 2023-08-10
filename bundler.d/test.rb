group :test do
  gem 'benchmark-ips'
  gem 'ci_reporter', '>= 1.6.3', "< 2.0.0", :require => false

  # Technically this is a hard dependency of the facts module but that's only
  # used in discovery. This at least allows us to run the tests on it
  gem 'facter', :require => false
  gem 'mocha', '~> 1.10', :require => false
  gem 'rack-test'
  gem 'rake'
  gem 'rubocop', '~> 1.56.0'
  gem 'rubocop-performance', '~> 1.5.2'
  gem 'rubocop-rake'
  gem 'ruby-prof', '< 1.4'
  gem 'test-unit'
  gem 'webmock'
end
