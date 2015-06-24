require 'test_helper'
require 'dhcp_native_ms/dhcp_native_ms_main'

class MsNativeDhcpProviderInterfaceTest < Test::Unit::TestCase
  def test_provider_interface
    assert_dhcp_provider_interface(Proxy::DHCP::NativeMS::Provider)
  end
end
