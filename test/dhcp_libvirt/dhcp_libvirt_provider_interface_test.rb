require 'test_helper'
require 'dhcp_libvirt/dhcp_libvirt_main'

class LibvirtDhcpProviderInterfaceTest < Test::Unit::TestCase
  def test_provider_interface
    ::Libvirt.stubs(:open).returns(true)
    assert_dhcp_provider_interface(::Proxy::DHCP::Libvirt::Provider.new(nil, nil, nil))
  end
end
