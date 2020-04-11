source 'https://rubygems.org'

gemspec

gem 'concurrent-ruby', '~> 1.0', require: 'concurrent'

Dir["#{File.dirname(__FILE__)}/bundler.d/*.rb"].each do |bundle|
  instance_eval(Bundler.read_file(bundle))
end
