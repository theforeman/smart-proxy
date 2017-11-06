group :test do
  gem 'mocha', '> 0.13.0', :require => false
  gem 'rack-test'
  gem 'single_test'
  gem 'ci_reporter', '>= 1.6.3', "< 2.0.0", :require => false
  gem 'rdoc'
  gem 'test-unit' if RUBY_VERSION > "1.8.7"
  gem 'addressable', '~> 2.3.8' if RUBY_VERSION == '1.8.7' # 2.4.0 drops support for ruby 1.8.7
  gem 'public_suffix', '< 3' if RUBY_VERSION < '2.1'
  gem 'benchmark-ips'
  gem 'ruby-prof'
  gem 'rubocop', '0.38.0' if RUBY_VERSION > "1.9.2"

  if RUBY_VERSION < '1.9.3'
    gem 'rake', '< 11'
    gem 'webmock', '< 2.0.0'
  else
    gem 'rake'
    gem 'rubocop-checkstyle_formatter', '~> 0.2'
    gem 'webmock'
  end
end
