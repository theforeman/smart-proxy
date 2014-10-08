group :test do
  gem 'mocha', '> 0.13.0', :require => false
  gem 'rake'
  gem 'rack-test'
  gem 'single_test'
  gem 'ci_reporter', '>= 1.6.3', "< 2.0.0", :require => false
  gem 'rdoc'
  gem 'minitest', '~> 4.7', :platforms => :ruby_19
  gem 'webmock'
  gem 'mixlib-shellout', '< 1.6.0'
end
