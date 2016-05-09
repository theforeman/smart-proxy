require 'test_helper'
require 'dhcp/dhcp_plugin'

class DhcpConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::DhcpPlugin.load_test_settings({})
    assert_equal '127.0.0.1', Proxy::DhcpPlugin.settings.server
    assert_equal 'dhcp_isc', Proxy::DhcpPlugin.settings.use_provider
    assert_equal [], Proxy::DhcpPlugin.settings.subnets
  end
end
