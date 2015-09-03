require 'test_helper'
require 'dhcp/dhcp_plugin'

class DhcpConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::DhcpPlugin.load_test_settings({})
    assert_equal 'isc', Proxy::DhcpPlugin.settings.dhcp_provider
    assert_equal '127.0.0.1', Proxy::DhcpPlugin.settings.dhcp_server
    assert_equal '7911', Proxy::DhcpPlugin.settings.dhcp_omapi_port
  end
end
