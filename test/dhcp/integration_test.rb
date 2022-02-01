require 'test_helper'
require 'dhcp/dhcp'
require 'dhcp/dhcp_api'
require 'dhcp_common/server'
require 'dhcp_common/subnet_service'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/record/reservation'

class DhcpApiValidIPTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    app = Proxy::DhcpApi.new
    app.helpers.server = @server
    app
  end

  def setup
    @service = Proxy::DHCP::SubnetService.initialized_instance
    @free_ips = Object.new
    @server = Proxy::DHCP::Server.new("testcase", nil, @service, @free_ips)
    @server.stubs(:unused_ip).returns(true)

    @subnet = Proxy::DHCP::Subnet.new("109.51.100.0", "255.255.255.0")
    @service.add_subnet(@subnet)

    @record = Proxy::DHCP::Reservation.new('test', "109.51.100.11", "aa:bb:cc:dd:ee:ff", @subnet, :hostname => 'test', :deleteable => true)
    @service.add_host(@subnet.network, @record)
  end

  def test_validate_ip_lower_bounds
    get "/192.0.2.0/unused_ip?mac=01:02:03:04:05:06&from=198.51.100.0&to=203.0.113.0"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_validate_ip_upper_bounds
    get "/192.88.99.255/unused_ip?mac=01:02:03:04:05:06&from=198.51.100.255&to=203.0.113.255"
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
  end

  def test_validate_ip_invalid
    get "/392.88.99.255/unused_ip?mac=01:02:03:04:05:06&from=198.51.100.255&to=203.0.113.255"
    assert_equal 400, last_response.status
  end
end
