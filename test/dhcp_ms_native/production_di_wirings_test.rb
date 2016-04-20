require 'test_helper'
require 'dhcp_common/subnet_service'
require 'dhcp_native_ms/configuration_loader'

class NativeMsProductionDIWiringsTest < Test::Unit::TestCase
  def test_provider_initialization
    container = ::Proxy::DependencyInjection::Container.new
    ::Proxy::DHCP::NativeMS::PluginConfiguration.new.load_dependency_injection_wirings(container, :server => "a_server")

    provider = container.get_dependency(:dhcp_provider)

    assert_equal "a_server", provider.name
    assert_equal ::Proxy::DHCP::SubnetService, provider.service.class
  end
end
