require 'test_helper'
require 'dhcp/dhcp_plugin'

class DhcpConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    Proxy::DhcpPlugin.load_test_settings({})
    assert_equal 'isc', Proxy::DhcpPlugin.settings.dhcp_provider
  end
end
