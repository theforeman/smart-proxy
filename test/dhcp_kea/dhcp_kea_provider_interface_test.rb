require 'test_helper'
require 'dhcp_kea/dhcp_kea_main'

class KeaDhcpProviderInterfaceTest < Test::Unit::TestCase
  def test_provider_interface
    kea_client = mock('kea_client')
    kea_client.stubs(:list_subnets).returns([])

    subnet_service = Proxy::DHCP::SubnetService.initialized_instance
    free_ips = Proxy::DHCP::FreeIps.new

    provider = ::Proxy::DHCP::Kea::Provider.new(kea_client, subnet_service, free_ips, 60)

    assert_dhcp_provider_interface(provider)
  end
end
