group :test do
  gem 'mocha', '> 0.13.0', :require => false
  gem 'rake'
  gem 'rack-test'
  gem 'single_test'
  gem 'ci_reporter', '>= 1.6.3'
  gem 'rdoc'
  gem 'minitest', :platforms => :ruby_19
end
