require 'test_helper'
require 'dhcp/dhcp/dhcp_plugin'

class DhcpConfigTest < Test::Unit::TestCase
  def test_omitted_settings_have_default_values
    assert_equal 'isc', Proxy::DhcpPlugin.plugin_default_settings[:dhcp_provider]
  end
end