group :test do
  gem 'benchmark-ips'

  # Technically this is a hard dependency of the facts module but that's only
  # used in discovery. This at least allows us to run the tests on it
  gem 'facter', :require => false
  gem 'minitest'
  gem 'minitest-reporters', :require => false
  gem 'mocha', '~> 3.1.0', :require => false
  gem 'rack-test'
  gem 'rake'
  gem 'rubocop', '~> 1.88.0'
  gem 'rubocop-performance', '~> 1.26.0'
  gem 'rubocop-rake'
  gem 'ruby-prof', '< 1.4'
  gem 'webmock'
end
