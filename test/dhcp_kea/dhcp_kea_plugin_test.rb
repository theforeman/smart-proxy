require 'test_helper'
require 'dhcp_kea/dhcp_kea'

class DhcpKeaPluginTest < ::Test::Unit::TestCase
  def test_plugin_loads
    assert_nothing_raised do
      Proxy::DHCP::Kea::Plugin.load_test_settings
    end
  end

  def test_default_settings
    Proxy::DHCP::Kea::Plugin.load_test_settings

    assert_equal 'http://127.0.0.1:8000/', Proxy::DHCP::Kea::Plugin.settings.dhcp_kea_url
    assert_equal true, Proxy::DHCP::Kea::Plugin.settings.dhcp_kea_verify_ssl
    assert_equal 60, Proxy::DHCP::Kea::Plugin.settings.dhcp_kea_lease_timeout
  end

  def test_plugin_capabilities
    Proxy::DHCP::Kea::Plugin.load_test_settings

    assert Proxy::DHCP::Kea::Plugin.capabilities.include?('dhcp_filename_ipv4')
    assert Proxy::DHCP::Kea::Plugin.capabilities.include?('dhcp_filename_hostname')
  end

  def test_requires_dhcp_plugin
    Proxy::DHCP::Kea::Plugin.load_test_settings

    assert Proxy::DHCP::Kea::Plugin.plugin_name == :dhcp_kea
  end
end
