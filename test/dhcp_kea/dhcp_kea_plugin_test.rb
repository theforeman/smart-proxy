require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp_kea/dhcp_kea'

class DhcpKeaPluginTest < ::Test::Unit::TestCase
  def test_default_settings
    Proxy::DHCP::Kea::Plugin.load_test_settings
    settings = Proxy::DHCP::Kea::Plugin.settings

    assert_equal true, settings.dhcp_kea_verify_ssl
    assert_equal 5, settings.dhcp_kea_http_timeout
    assert_equal 1800, settings.blacklist_duration_seconds
  end

  def test_capabilities
    assert_equal ['dhcp_filename_hostname', 'dhcp_filename_ipv4'],
                 Proxy::DHCP::Kea::Plugin.capabilities.sort
  end

  def test_dhcp_kea_url_is_required
    settings = Proxy::DHCP::Kea::Plugin.default_settings
    loader = Proxy::DefaultModuleLoader.new(Proxy::DHCP::Kea::Plugin, ::Proxy::DependencyInjection::Container.new)

    error = assert_raise(Proxy::Error::ConfigurationError) do
      loader.validate_settings(Proxy::DHCP::Kea::Plugin, settings)
    end

    assert_match "Kea API URL is missing", error.message
    assert_match "config/settings.d/dhcp_kea.yml", error.message
    assert_match "config/settings.d/dhcp_kea.yml.example", error.message
  end
end
