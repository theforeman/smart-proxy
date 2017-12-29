group :development do
  # To use debugger
  gem "ruby-debug", :platforms => :ruby_18
  gem "ruby-debug19", :platforms => :ruby_19
  gem 'single_test'
  gem 'pry'

  if RUBY_VERSION < '2.2'
    gem 'rdoc', '< 6'
  else
    gem 'rdoc'
  end
end
