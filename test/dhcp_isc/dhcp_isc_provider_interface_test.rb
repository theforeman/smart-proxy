require 'test_helper'
require 'dhcp_isc/dhcp_isc_main'

class IscDhcpProviderInterfaceTest < Test::Unit::TestCase
  def test_provider_interface
    assert_dhcp_provider_interface(Proxy::DHCP::ISC::Provider.new({}, nil))
  end
end
