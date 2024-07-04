source 'https://rubygems.org'

gemspec

gem 'concurrent-ruby', '~> 1.0', require: 'concurrent'

# FFI 1.17 needs rubygems 3.3.22+, which is Ruby 3.0+ only
gem "ffi", "<1.17" if RUBY_VERSION < '3.0'

Dir[File.join(__dir__, 'bundler.d', '*.rb')].each do |bundle|
  eval_gemfile(bundle)
end
