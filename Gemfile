source 'https://rubygems.org'

gemspec

if RUBY_VERSION < '2.2'
  gem 'sinatra', '< 2'
  gem 'rack', '>= 1.1', '< 2.0.0'
else
  gem 'sinatra'
  gem 'rack', '>= 1.1'
end

Dir["#{File.dirname(__FILE__)}/bundler.d/*.rb"].each do |bundle|
  self.instance_eval(Bundler.read_file(bundle))
end
