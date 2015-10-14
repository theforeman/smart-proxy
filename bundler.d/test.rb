group :test do
  gem 'mocha', '> 0.13.0', :require => false
  gem 'rake'
  gem 'rack-test'
  gem 'single_test'
  gem 'ci_reporter', '>= 1.6.3', "< 2.0.0", :require => false
  gem 'rdoc'
  gem 'test-unit', :platforms => [:ruby_19, :ruby_20, :ruby_21, :ruby_22]
  gem 'webmock'
  gem 'rubocop-checkstyle_formatter' if RUBY_VERSION > "1.9.2"
end
