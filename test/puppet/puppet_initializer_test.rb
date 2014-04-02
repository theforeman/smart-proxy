require 'test_helper'
require 'puppet/puppet_plugin'
require 'puppet/initializer'

class PuppetInitializerTest < Test::Unit::TestCase
  def setup
    Proxy::Puppet::Plugin.load_test_settings({})
  end

  def test_config_returns_puppet_conf
    Proxy::Puppet::Plugin.settings.expects(:puppet_conf).returns('/foo/puppet.conf')
    assert_equal '/foo/puppet.conf', Proxy::Puppet::Initializer.config
  end

  def test_config_returns_puppetdir
    Proxy::Puppet::Plugin.settings.expects(:puppetdir).returns('/foo')
    assert_equal '/foo/puppet.conf', Proxy::Puppet::Initializer.config
  end

  def test_config_returns_default
    assert_equal '/etc/puppet/puppet.conf', Proxy::Puppet::Initializer.config
  end
end
