require 'test_helper'
require 'puppetca/puppetca_plugin'

class PuppetCAConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::PuppetCa::Plugin.load_test_settings({})
    assert_equal '/var/lib/puppet/ssl', Proxy::PuppetCa::Plugin.settings.ssldir
    assert_equal '/etc/puppet/autosign.conf', Proxy::PuppetCa::Plugin.settings.autosignfile
  end
end
