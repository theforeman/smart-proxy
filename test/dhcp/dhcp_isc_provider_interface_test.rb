require 'test_helper'
require 'dhcp_common/isc/omapi_provider'

class IscDhcpProviderInterfaceTest < Test::Unit::TestCase
  def test_provider_interface
    assert_dhcp_provider_interface(Proxy::DHCP::CommonISC::IscOmapiProvider.new({}, nil))
  end
end
