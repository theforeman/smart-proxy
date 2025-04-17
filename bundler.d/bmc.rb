group :bmc do
  gem 'rubyipmi', '>= 0.10.0'
  gem 'redfish_client', '>= 0.6.0'
  # observer is a transitive dependency of rubyipmi
  # Changed from a default gem to a bundled gem in Ruby 3.4 See https://stdgems.org/new-in/3.4/
  # This is a workaround, till https://github.com/logicminds/rubyipmi/pull/61 is live
  gem 'observer' if RUBY_VERSION >= '3.4'
end
