require 'test_helper'
require 'puppetca/puppetca'

class PuppetCAConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::PuppetCa::Plugin.load_test_settings({})
    assert_equal '/var/lib/puppet/ssl', Proxy::PuppetCa::Plugin.settings.ssldir
    assert_equal false, Proxy::PuppetCa::Plugin.settings.sign_all
  end
end
