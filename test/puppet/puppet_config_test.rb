require 'test_helper'
require 'puppet/puppet_plugin'

class PuppetConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    assert_equal 'puppetrun', Proxy::Puppet::Plugin.settings.puppet_provider
    assert_equal '/etc/puppet', Proxy::Puppet::Plugin.settings.puppetdir
  end
end