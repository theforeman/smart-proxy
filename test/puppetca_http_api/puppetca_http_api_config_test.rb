require 'test_helper'
require 'puppetca_http_api/puppetca_http_api'

class PuppetCaHttpApiConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::PuppetCa::PuppetcaHttpApi::Plugin.load_test_settings({})
    assert_equal '/etc/puppetlabs/puppet/ssl/certs/ca.pem', Proxy::PuppetCa::PuppetcaHttpApi::Plugin.settings.puppet_ssl_ca
  end
end
