require 'test_helper'
require 'dhcp_common/subnet_service'
require 'dhcp_common/free_ips'
require 'dhcp_kea/kea_api_client'
require 'dhcp_kea/dhcp_kea_main'

class DhcpKeaProductionDIWiringsTest < Test::Unit::TestCase
  def setup
    @settings = {
      :dhcp_kea_url => 'http://127.0.0.1:8000/',
      :dhcp_kea_verify_ssl => true,
      :dhcp_kea_lease_timeout => 60,
    }
  end

  def test_kea_api_client_initialization
    client = ::Proxy::DHCP::Kea::KeaApiClient.new(
      @settings[:dhcp_kea_url],
      nil,
      nil,
      verify_ssl: @settings[:dhcp_kea_verify_ssl]
    )

    assert_not_nil client
    assert_equal 'http://127.0.0.1:8000', client.api_url
    assert_nil client.username
    assert_nil client.password
    assert_equal true, client.verify_ssl
  end

  def test_subnet_service_initialization
    service = ::Proxy::DHCP::SubnetService.initialized_instance
    assert_not_nil service
    assert_instance_of ::Proxy::DHCP::SubnetService, service
  end

  def test_free_ips_initialization
    free_ips = ::Proxy::DHCP::FreeIps.new
    assert_not_nil free_ips
  end

  def test_provider_initialization
    kea_client = ::Proxy::DHCP::Kea::KeaApiClient.new(
      @settings[:dhcp_kea_url],
      nil,
      nil,
      verify_ssl: @settings[:dhcp_kea_verify_ssl]
    )
    kea_client.stubs(:list_subnets).returns([])

    subnet_service = ::Proxy::DHCP::SubnetService.initialized_instance
    free_ips = ::Proxy::DHCP::FreeIps.new

    provider = ::Proxy::DHCP::Kea::Provider.new(
      kea_client,
      subnet_service,
      free_ips,
      @settings[:dhcp_kea_lease_timeout]
    )

    assert_not_nil provider
    assert_instance_of ::Proxy::DHCP::Kea::Provider, provider
    assert_equal @settings[:dhcp_kea_lease_timeout], provider.lease_timeout
  end

  def test_kea_api_client_with_authentication
    client = ::Proxy::DHCP::Kea::KeaApiClient.new(
      @settings[:dhcp_kea_url],
      'admin',
      'secret',
      verify_ssl: @settings[:dhcp_kea_verify_ssl]
    )

    assert_equal 'admin', client.username
    assert_equal 'secret', client.password
  end
end
