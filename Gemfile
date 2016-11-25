source 'https://rubygems.org'

gemspec

gem 'json', '< 2.0.0', :require => false if RUBY_VERSION < '2.0.0'

Dir["#{File.dirname(__FILE__)}/bundler.d/*.rb"].each do |bundle|
  self.instance_eval(Bundler.read_file(bundle))
end
