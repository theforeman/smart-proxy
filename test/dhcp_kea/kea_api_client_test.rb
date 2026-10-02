require 'test_helper'
require 'dhcp_kea/kea_api_client'
require 'webmock/test_unit'

class KeaApiClientTest < ::Test::Unit::TestCase
  def setup
    @api_url = 'http://kea-server:8000'
    @client = Proxy::DHCP::Kea::KeaApiClient.new(@api_url)
  end

  def teardown
    WebMock.reset!
  end

  def test_initialize
    client = Proxy::DHCP::Kea::KeaApiClient.new('http://example.com:8000/', 'admin', 'secret', verify_ssl: false)

    assert_equal 'http://example.com:8000', client.api_url
    assert_equal 'admin', client.username
    assert_equal 'secret', client.password
    assert_equal false, client.verify_ssl
  end

  def test_send_command_success
    stub_request(:post, "#{@api_url}/")
      .with(
        body: {
          'command' => 'test-command',
          'service' => ['dhcp4'],
          'arguments' => {'key' => 'value'},
        }.to_json
      )
      .to_return(
        status: 200,
        body: [{'result' => 0, 'text' => 'Success', 'arguments' => {'data' => 'result'}}].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    result = @client.send_command('dhcp4', 'test-command', {'key' => 'value'})

    assert_equal({'data' => 'result'}, result)
  end

  def test_send_command_failure
    stub_request(:post, "#{@api_url}/")
      .to_return(
        status: 200,
        body: [{'result' => 1, 'text' => 'Command failed'}].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    assert_raise(RuntimeError) do
      @client.send_command('dhcp4', 'test-command', {})
    end
  end

  def test_send_command_http_error
    stub_request(:post, "#{@api_url}/")
      .to_return(status: 500, body: 'Internal Server Error')

    assert_raise(RuntimeError) do
      @client.send_command('dhcp4', 'test-command', {})
    end
  end

  def test_list_subnets
    stub_request(:post, "#{@api_url}/")
      .with(
        body: hash_including('command' => 'config-get')
      )
      .to_return(
        status: 200,
        body: [{
          'result' => 0,
          'text' => 'Success',
          'arguments' => {
            'Dhcp4' => {
              'subnet4' => [
                {'subnet' => '192.168.1.0/24', 'id' => 1},
                {'subnet' => '10.0.0.0/8', 'id' => 2},
              ],
            },
          },
        }].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    subnets = @client.list_subnets

    assert_equal 2, subnets.length
    assert_equal '192.168.1.0/24', subnets[0]['subnet']
    assert_equal 1, subnets[0]['id']
  end

  def test_add_reservation
    stub_request(:post, "#{@api_url}/")
      .with(
        body: hash_including(
          'command' => 'reservation-add',
          'service' => ['dhcp4']
        )
      )
      .to_return(
        status: 200,
        body: [{'result' => 0, 'text' => 'Host added.'}].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    result = @client.add_reservation(1, '192.168.1.50', 'aa:bb:cc:dd:ee:ff', 'test.example.com')

    assert_not_nil result
  end

  def test_add_reservation_with_pxe_options
    stub_request(:post, "#{@api_url}/")
      .with(
        body: hash_including(
          'command' => 'reservation-add',
          'arguments' => hash_including(
            'next-server' => '192.168.1.1',
            'boot-file-name' => 'pxelinux.0'
          )
        )
      )
      .to_return(
        status: 200,
        body: [{'result' => 0, 'text' => 'Host added.'}].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    result = @client.add_reservation(
      1,
      '192.168.1.50',
      'aa:bb:cc:dd:ee:ff',
      'test.example.com',
      {next_server: '192.168.1.1', boot_file_name: 'pxelinux.0'}
    )

    assert_not_nil result
  end

  def test_delete_reservation_by_ip
    stub_request(:post, "#{@api_url}/")
      .with(
        body: hash_including(
          'command' => 'reservation-del',
          'arguments' => hash_including('ip-address' => '192.168.1.50')
        )
      )
      .to_return(
        status: 200,
        body: [{'result' => 0, 'text' => 'Host deleted.'}].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    result = @client.delete_reservation_by_ip(1, '192.168.1.50')

    assert_not_nil result
  end

  def test_reservation_by_ip_found
    stub_request(:post, "#{@api_url}/")
      .with(
        body: hash_including('command' => 'reservation-get')
      )
      .to_return(
        status: 200,
        body: [{
          'result' => 0,
          'text' => 'Success',
          'arguments' => {'ip-address' => '192.168.1.50', 'hw-address' => 'aa:bb:cc:dd:ee:ff'},
        }].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    result = @client.reservation_by_ip(1, '192.168.1.50')

    assert_not_nil result
    assert_equal '192.168.1.50', result['ip-address']
  end

  def test_reservation_by_ip_not_found
    stub_request(:post, "#{@api_url}/")
      .to_return(
        status: 200,
        body: [{'result' => 3, 'text' => 'reservation not found'}].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    result = @client.reservation_by_ip(1, '192.168.1.99')

    assert_nil result
  end

  def test_lease_by_ip
    stub_request(:post, "#{@api_url}/")
      .with(
        body: hash_including('command' => 'lease4-get')
      )
      .to_return(
        status: 200,
        body: [{
          'result' => 0,
          'text' => 'Success',
          'arguments' => {
            'leases' => [
              {'ip-address' => '192.168.1.50', 'hw-address' => 'aa:bb:cc:dd:ee:ff'},
            ],
          },
        }].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    result = @client.lease_by_ip('192.168.1.50')

    assert_not_nil result
    assert_equal '192.168.1.50', result['ip-address']
  end

  def test_http_basic_auth
    client = Proxy::DHCP::Kea::KeaApiClient.new(@api_url, 'admin', 'secret')

    stub_request(:post, "#{@api_url}/")
      .with(
        headers: {'Authorization' => 'Basic YWRtaW46c2VjcmV0'}  # base64('admin:secret')
      )
      .to_return(
        status: 200,
        body: [{'result' => 0, 'text' => 'Success', 'arguments' => {}}].to_json,
        headers: {'Content-Type' => 'application/json'}
      )

    result = client.send_command('dhcp4', 'test', {})

    assert_not_nil result
  end
end
