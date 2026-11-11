require 'test_helper'
require 'dhcp_common/dhcp_common'
require 'dhcp_kea/kea_api_client'
require 'dhcp_kea/dhcp_kea_main'

class KeaDhcpProviderInterfaceTest < Test::Unit::TestCase
  def test_provider_interface
    assert_dhcp_provider_interface(::Proxy::DHCP::Kea::Provider.new(nil))
  end
end
