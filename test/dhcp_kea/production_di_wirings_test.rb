require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp_kea/dhcp_kea'
require 'dhcp_common/free_ips'
require 'dhcp_kea/kea_api_client'
require 'dhcp_kea/dhcp_kea_main'

class DhcpKeaProductionDIWiringsTest < Test::Unit::TestCase
  def setup
    @container = ::Proxy::DependencyInjection::Container.new
    Proxy::DHCP::Kea::Plugin.di_wirings.load_dependency_injection_wirings(@container,
                                                                          :dhcp_kea_url => 'https://kea.example.com:8000/', :dhcp_kea_username => 'foreman', :dhcp_kea_password => 'secret',
                                                                          :dhcp_kea_verify_ssl => false, :dhcp_kea_http_timeout => 3, :subnets => ['192.168.1.0/255.255.255.0'],
                                                                          :blacklist_duration_minutes => 10)
  end

  def test_kea_api_client_wiring
    client = @container.get_dependency(:kea_api_client)
    assert_equal 'https://kea.example.com:8000/', client.api_url.to_s
    assert_equal ['foreman', 'secret'], [client.username, client.password]
    assert_equal false, client.verify_ssl
    assert_equal 3, client.timeout
  end

  def test_provider_wiring
    provider = @container.get_dependency(:dhcp_provider)
    assert_same @container.get_dependency(:kea_api_client), provider.kea_client
    assert_same @container.get_dependency(:free_ips), provider.free_ips
    assert_equal Set.new(['192.168.1.0/255.255.255.0']), provider.managed_subnets
    assert_equal 10, provider.free_ips.blacklist_interval
  end

  def test_provider_is_created_per_request
    refute_same @container.get_dependency(:dhcp_provider), @container.get_dependency(:dhcp_provider)
  end
end
