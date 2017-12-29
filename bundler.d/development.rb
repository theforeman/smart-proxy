group :development do
  # To use debugger
  gem "ruby-debug", :platforms => :ruby_18
  gem "ruby-debug19", :platforms => :ruby_19
  gem 'single_test'
  gem 'pry'
  gem 'rubocop', '0.38.0' if  RUBY_VERSION > "1.9.2"
  gem 'benchmark-ips'
  gem 'ruby-prof'

  if RUBY_VERSION < '2.2'
    gem 'rdoc', '< 6'
  else
    gem 'rdoc'
  end
end
