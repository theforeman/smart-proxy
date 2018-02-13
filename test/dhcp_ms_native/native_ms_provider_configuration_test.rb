require 'test_helper'
require 'dhcpsapi'
require 'dhcp_native_ms/plugin_configuration'
require 'dhcp_native_ms/dhcp_native_ms_main'

class NativeMsProviderConfigurationTest < Test::Unit::TestCase
  def setup
    @configuration = ::Proxy::DHCP::NativeMS::PluginConfiguration.new
    @container = ::Proxy::DependencyInjection::Container.new
  end

  def test_dhcpsapi_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container, :server => '192.168.42.1')
    assert_equal '192.168.42.1', @container.get_dependency(:dhcps_api).server_ip_address
  end

  def test_provider_wiring_parameters
    @configuration.load_dependency_injection_wirings(@container, :subnets => ['192.168.42.0'], :disable_ddns => true)

    assert_equal Set.new(['192.168.42.0']), @container.get_dependency(:dhcp_provider).managed_subnets
    assert @container.get_dependency(:dhcp_provider).disable_ddns
    assert @container.get_dependency(:dhcp_provider).free_ips
  end
end
