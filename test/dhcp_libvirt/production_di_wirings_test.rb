require 'test_helper'
require 'dhcp_common/subnet_service'
require 'dhcp_libvirt/libvirt_dhcp_network'
require 'dhcp_libvirt/dhcp_libvirt_main'
require 'dhcp_libvirt/configuration_loader'

class DhcpLibvirtProductionDIWiringsTest < Test::Unit::TestCase
  def setup
    @settings = {:network => "a_network", :url => "qemu:///system"}
    @container = ::Proxy::DependencyInjection::Container.new
    ::Proxy::DHCP::Libvirt::PluginConfiguration.new.load_dependency_injection_wirings(@container, @settings)
  end

  def test_provider_initialization
    provider = @container.get_dependency(:dhcp_provider)
    assert_equal @settings[:network], provider.network
  end

  def test_libvirt_network_initialization
    network = @container.get_dependency(:libvirt_network)
    assert_equal @settings[:url], network.url
    assert_equal @settings[:network], network.network
  end
end
