source 'https://rubygems.org'

gemspec

gem 'concurrent-ruby', '~> 1.0', require: 'concurrent'

Dir[File.join(__dir__, 'bundler.d', '*.rb')].each do |bundle|
  eval_gemfile(bundle)
end

# Changed from a default gem to a bundled gem in Ruby 3.4
# See: https://stdgems.org/new-in/3.4/
gem 'syslog', '>= 0.3.0' if RUBY_VERSION >= '3.4'
