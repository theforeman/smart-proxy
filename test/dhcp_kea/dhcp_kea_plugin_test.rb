require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp_kea/dhcp_kea'

class DhcpKeaPluginTest < ::Test::Unit::TestCase
  def test_default_settings
    Proxy::DHCP::Kea::Plugin.load_test_settings
    settings = Proxy::DHCP::Kea::Plugin.settings

    assert_equal 'http://127.0.0.1:8000/', settings.dhcp_kea_url
    assert_equal true, settings.dhcp_kea_verify_ssl
    assert_equal 5, settings.dhcp_kea_http_timeout
    assert_equal 1800, settings.blacklist_duration_minutes
  end

  def test_capabilities
    assert_equal ['dhcp_filename_hostname', 'dhcp_filename_ipv4'], Proxy::DHCP::Kea::Plugin.capabilities.sort
  end
end
