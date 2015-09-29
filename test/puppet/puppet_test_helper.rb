require 'puppet_proxy/puppet'
require 'puppet_proxy/initializer'

Proxy::Puppet::Plugin.load_test_settings(:puppet_conf => './test/fixtures/puppet.conf')
Proxy::Puppet::Initializer.new.reset_puppet
