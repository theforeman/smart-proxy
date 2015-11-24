group :development do
  # To use debugger
  gem "ruby-debug", :platforms => :ruby_18
  gem "ruby-debug19", :platforms => :ruby_19
  gem 'rdoc'
  gem 'single_test'
  gem 'pry'
  gem 'rubocop', '0.35.1' if  RUBY_VERSION > "1.9.2"
end
