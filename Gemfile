source 'https://rubygems.org'

gemspec

if RUBY_VERSION < '2.2'
  gem 'sinatra', '< 2'
  gem 'rack', '>= 1.3', '< 2.0.0'
end
gem 'concurrent-ruby', '~> 1.0', require: 'concurrent'

Dir["#{File.dirname(__FILE__)}/bundler.d/*.rb"].each do |bundle|
  self.instance_eval(Bundler.read_file(bundle))
end
