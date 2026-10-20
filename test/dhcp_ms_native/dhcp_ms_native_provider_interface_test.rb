require 'test_helper'
require 'dhcp_native_ms/dhcp_native_ms_main'

class MsNativeDhcpProviderInterfaceTest < Minitest::Test
  def test_provider_interface
    assert_dhcp_provider_interface(Proxy::DHCP::NativeMS::Provider.new(nil, nil, nil))
  end
end
