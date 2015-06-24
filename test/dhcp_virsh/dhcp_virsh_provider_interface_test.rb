require 'test_helper'
require 'dhcp_virsh/dhcp_virsh_main'

class VirshDhcpProviderInterfaceTest < Test::Unit::TestCase
  def test_provider_interface
    assert_dhcp_provider_interface(::Proxy::DHCP::Virsh::Provider)
  end
end
