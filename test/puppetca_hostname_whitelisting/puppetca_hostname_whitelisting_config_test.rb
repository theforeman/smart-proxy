require 'test_helper'
require 'puppetca/puppetca'
require 'puppetca_hostname_whitelisting/puppetca_hostname_whitelisting'
require 'puppetca_hostname_whitelisting/puppetca_hostname_whitelisting_plugin'

class PuppetCaHostnameWhitelistingConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::PuppetCa::HostnameWhitelisting::Plugin.load_test_settings({})
    assert_equal '/etc/puppet/autosign.conf', Proxy::PuppetCa::HostnameWhitelisting::Plugin.settings.autosignfile
  end
end
