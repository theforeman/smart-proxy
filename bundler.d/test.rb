group :test do
  gem 'mocha', '> 0.13.0', :require => false
  gem 'rack-test'
  gem 'single_test'
  gem 'ci_reporter', '>= 1.6.3', "< 2.0.0", :require => false
  gem 'rdoc'
  gem 'minitest', '~> 4.7', :platforms => :ruby_19
  gem 'addressable', '~> 2.3.8' if RUBY_VERSION == '1.8.7' # 2.4.0 drops support for ruby 1.8.7
  gem 'webmock'
  gem 'rubocop-checkstyle_formatter' if RUBY_VERSION > "1.9.2"
  gem 'rake', '< 11'
end
