require 'test_helper'

class PuppetInitializerTest < Test::Unit::TestCase

  def test_config_returns_puppet_conf
    SETTINGS.expects(:puppet_conf).returns('/foo/puppet.conf')
    assert_equal '/foo/puppet.conf', Proxy::Puppet::Initializer.config
  end

  def test_config_returns_puppetdir
    SETTINGS.stubs(:puppet_conf).returns(nil)
    SETTINGS.expects(:puppetdir).returns('/foo')
    assert_equal '/foo/puppet.conf', Proxy::Puppet::Initializer.config
  end

  def test_config_returns_default
    SETTINGS.stubs(:puppet_conf).returns(nil)
    SETTINGS.expects(:puppetdir).returns(nil)
    assert_equal '/etc/puppet/puppet.conf', Proxy::Puppet::Initializer.config
  end

end
