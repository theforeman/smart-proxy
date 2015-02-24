source 'http://rubygems.org'

gem 'json'
gem 'sinatra'
gem 'route53'
gem 'rack', '>= 1.1', '< 1.6'

Dir["#{File.dirname(__FILE__)}/bundler.d/*.rb"].each do |bundle|
 # puts "adding custom gem file #{bundle}"
  self.instance_eval(Bundler.read_file(bundle))
end
