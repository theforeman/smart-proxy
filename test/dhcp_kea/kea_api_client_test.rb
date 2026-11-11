require 'test_helper'
require 'dhcp_common/dhcp_common'
require 'dhcp_kea/kea_api_client'
require 'webmock/test_unit'

class KeaApiClientTest < ::Test::Unit::TestCase
  URL = 'http://kea.example.com:8000/'.freeze

  def setup
    @client = Proxy::DHCP::Kea::KeaApiClient.new(URL, 'foreman', 'secret')
  end

  def stub_kea(command, arguments = nil, response = {'result' => 0, 'text' => 'ok'})
    body = {'command' => command, 'service' => ['dhcp4']}
    body['arguments'] = arguments if arguments
    stub_request(:post, URL).with(body: body.to_json, basic_auth: ['foreman', 'secret']).to_return(body: [response].to_json)
  end

  def test_send_command_returns_arguments
    stub_kea('version-get', nil, 'result' => 0, 'arguments' => {'extended' => '3.2.1'})
    assert_equal({'extended' => '3.2.1'}, @client.send_command('version-get'))
  end

  def test_send_command_returns_nil_for_empty_result
    stub_kea('lease4-get', {'ip-address' => '192.168.1.5'}, 'result' => 3, 'text' => 'Lease not found.')
    assert_nil @client.lease_by_ip('192.168.1.5')
  end

  def test_send_command_raises_on_error
    stub_kea('reservation-add', {'reservation' => {}}, 'result' => 1, 'text' => 'Host database not available')
    error = assert_raises(Proxy::DHCP::Error) { @client.add_reservation({}) }
    assert_match(/Host database not available/, error.message)
  end

  def test_send_command_raises_on_unsupported_command
    stub_kea('reservation-get', {'subnet-id' => 1, 'ip-address' => '192.168.1.5'}, 'result' => 2, 'text' => "'reservation-get' command not supported.")
    error = assert_raises(Proxy::DHCP::Error) { @client.reservation_by_ip(1, '192.168.1.5') }
    assert_match(/hook library/, error.message)
  end

  def test_http_error
    stub_request(:post, URL).to_return(status: 401, body: 'Unauthorized')
    assert_raises(Proxy::DHCP::Error) { @client.send_command('version-get') }
  end

  def test_connection_error
    stub_request(:post, URL).to_raise(Errno::ECONNREFUSED)
    error = assert_raises(Proxy::DHCP::Error) { @client.send_command('version-get') }
    assert_match(/Unable to connect/, error.message)
  end

  def test_timeout
    stub_request(:post, URL).to_timeout
    assert_raises(Proxy::DHCP::Error) { @client.send_command('version-get') }
  end

  def test_invalid_json
    stub_request(:post, URL).to_return(body: 'not json')
    assert_raises(Proxy::DHCP::Error) { @client.send_command('version-get') }
  end

  def test_no_basic_auth_without_credentials
    stub_request(:post, URL).with { |request| !request.headers.key?('Authorization') }.to_return(body: [{'result' => 0}].to_json)
    Proxy::DHCP::Kea::KeaApiClient.new(URL).send_command('version-get')
  end

  def test_subnets_include_shared_networks
    config = {'Dhcp4' => {
      'subnet4' => [{'id' => 1, 'subnet' => '192.168.1.0/24'}],
      'shared-networks' => [{'name' => 'net', 'subnet4' => [{'id' => 2, 'subnet' => '10.0.0.0/8'}]}],
    }}
    stub_kea('config-get', nil, 'result' => 0, 'arguments' => config)
    assert_equal([1, 2], @client.subnets.map { |s| s['id'] })
  end

  def test_reservations_are_paged
    first = stub_kea('reservation-get-page', {'subnet-id' => 1, 'limit' => 1000},
                     'result' => 0, 'arguments' => {'count' => 1, 'hosts' => [{'ip-address' => '192.168.1.5'}], 'next' => {'from' => 1, 'source-index' => 1}})
    second = stub_kea('reservation-get-page', {'subnet-id' => 1, 'limit' => 1000, 'from' => 1, 'source-index' => 1},
                      'result' => 3, 'arguments' => {'count' => 0, 'hosts' => []})

    assert_equal [{'ip-address' => '192.168.1.5'}], @client.reservations(1)
    assert_requested first
    assert_requested second
  end

  def test_reservation_by_mac
    stub_kea('reservation-get', {'subnet-id' => 1, 'identifier-type' => 'hw-address', 'identifier' => 'aa:bb:cc:dd:ee:ff'},
             'result' => 0, 'arguments' => {'ip-address' => '192.168.1.5'})
    assert_equal({'ip-address' => '192.168.1.5'}, @client.reservation_by_mac(1, 'aa:bb:cc:dd:ee:ff'))
  end

  def test_add_reservation_wraps_arguments
    request = stub_kea('reservation-add', 'reservation' => {'subnet-id' => 1, 'ip-address' => '192.168.1.5'})
    @client.add_reservation('subnet-id' => 1, 'ip-address' => '192.168.1.5')
    assert_requested request
  end

  def test_delete_reservation_by_mac
    request = stub_kea('reservation-del', 'subnet-id' => 1, 'identifier-type' => 'hw-address', 'identifier' => 'aa:bb:cc:dd:ee:ff')
    @client.delete_reservation(1, 'aa:bb:cc:dd:ee:ff')
    assert_requested request
  end

  def test_leases
    stub_kea('lease4-get-all', {'subnets' => [1]}, 'result' => 0, 'arguments' => {'leases' => [{'ip-address' => '192.168.1.5'}]})
    assert_equal [{'ip-address' => '192.168.1.5'}], @client.leases(1)
  end

  def test_leases_empty
    stub_kea('lease4-get-all', {'subnets' => [1]}, 'result' => 3, 'arguments' => {'leases' => []})
    assert_equal [], @client.leases(1)
  end

  def test_lease_by_ip_returns_lease
    stub_kea('lease4-get', {'ip-address' => '192.168.1.5'}, 'result' => 0, 'arguments' => {'ip-address' => '192.168.1.5'})
    assert_equal({'ip-address' => '192.168.1.5'}, @client.lease_by_ip('192.168.1.5'))
  end

  def test_delete_lease
    request = stub_kea('lease4-del', 'ip-address' => '192.168.1.5')
    @client.delete_lease('192.168.1.5')
    assert_requested request
  end
end
