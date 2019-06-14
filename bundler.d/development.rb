group :development do
  # To use debugger
  gem 'single_test'
  gem 'pry'

  if RUBY_VERSION < '2.2'
    gem 'rdoc', '< 6'
  else
    gem 'rdoc'
  end
end
