source 'https://rubygems.org'

gemspec
# this cannot go into gemspec, bundler_ext fails to load this gem.
# see http://projects.theforeman.org/issues/16760
gem 'concurrent-ruby', '~> 1.0', require: 'concurrent'

Dir["#{File.dirname(__FILE__)}/bundler.d/*.rb"].each do |bundle|
  self.instance_eval(Bundler.read_file(bundle))
end
