require 'test_helper'
require 'puppet_proxy/puppet_plugin'

class PuppetConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::Puppet::Plugin.load_test_settings({})

    assert_equal 'puppetrun', Proxy::Puppet::Plugin.settings.puppet_provider
    assert_equal '/etc/puppet/puppet.conf', Proxy::Puppet::Plugin.settings.puppet_conf
    assert_equal 'puppet.run', Proxy::Puppet::Plugin.settings.salt_puppetrun_cmd
    assert_equal '/var/lib/puppet/ssl/certs/ca.pem', Proxy::Puppet::Plugin.settings.puppet_ssl_ca
    assert Proxy::Puppet::Plugin.settings.use_cache
  end
end
