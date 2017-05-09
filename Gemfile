source 'https://rubygems.org'

gemspec

gem 'sinatra', '< 2' if RUBY_VERSION < '2.2'

Dir["#{File.dirname(__FILE__)}/bundler.d/*.rb"].each do |bundle|
  self.instance_eval(Bundler.read_file(bundle))
end
