require 'test_helper'
require 'dhcp_common/subnet_service'
require 'dhcp_common/free_ips'
require 'dhcp_libvirt/libvirt_dhcp_network'
require 'dhcp_libvirt/dhcp_libvirt_main'
require 'dhcp_libvirt/configuration_loader'

class DhcpLibvirtProductionDIWiringsTest < Test::Unit::TestCase
  def setup
    @settings = {:network => "a_network", :url => "qemu:///system"}
    @container = ::Proxy::DependencyInjection::Container.new
    ::Proxy::DHCP::Libvirt::PluginConfiguration.new.load_dependency_injection_wirings(@container, @settings)
  end

  def test_libvirt_network_initialization
    network = @container.get_dependency(:libvirt_network)
    assert_equal @settings[:url], network.url
    assert_equal @settings[:network], network.network
  end

  def test_free_ips_initialization
    assert_not_nil @container.get_dependency(:free_ips)
  end

  def test_initialized_subnet_service_initialization
    expected_subnet_service = Object.new
    Proxy::DHCP::Libvirt::SubnetServiceInitializer.any_instance.expects(:initialized_subnet_service).
      with() {|v| v.instance_of?(Proxy::DHCP::SubnetService)}.
      returns(expected_subnet_service)
    assert_equal expected_subnet_service, @container.get_dependency(:initialized_subnet_service)
  end

  def test_provider_initialization
    expected_subnet_service = Object.new
    Proxy::DHCP::Libvirt::SubnetServiceInitializer.any_instance.expects(:initialized_subnet_service).returns(expected_subnet_service)
    provider = @container.get_dependency(:dhcp_provider)
    assert_equal @settings[:network], provider.network
    assert_equal expected_subnet_service, provider.service
    assert_not_nil provider.free_ips
  end
end
