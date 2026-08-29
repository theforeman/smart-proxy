require File.join(__dir__, '..', 'test_helper')
require 'json'
require 'wol/wol_api'

ENV['RACK_ENV'] = 'test'

class WolApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::WolApi.new
  end

  def setup
    # Mock UDPSocket to prevent actual network packets during tests
    @mock_socket = mock('UDPSocket')
    UDPSocket.stubs(:new).returns(@mock_socket)
    @mock_socket.stubs(:setsockopt)
    @mock_socket.stubs(:send)
    @mock_socket.stubs(:close)

    # By default, stub the packet sender to prevent actual network calls
    # Individual tests can override this if they need to test socket operations
    stub_packet_sender
  end

  def test_valid_mac_address_with_colons
    mac = "54:ee:75:87:1f:fb"

    post "/", :mac_address => mac

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal "success", data["status"]
    assert_equal "Wake-on-LAN packet sent successfully", data["message"]
    assert_equal mac, data["mac_address"]
  end

  def test_valid_mac_address_uppercase
    mac = "AA:BB:CC:DD:EE:FF"

    post "/", :mac_address => mac

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal "success", data["status"]
    # The validation system normalizes MAC addresses to lowercase
    assert_equal mac.downcase, data["mac_address"]
  end

  def test_valid_mac_address_lowercase
    mac = "aa:bb:cc:dd:ee:ff"

    post "/", :mac_address => mac

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal "success", data["status"]
    assert_equal mac, data["mac_address"]
  end

  def test_valid_mac_address_mixed_case
    mac = "Ab:Cd:Ef:12:34:56"

    post "/", :mac_address => mac

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal "success", data["status"]
    # The validation system normalizes MAC addresses to lowercase
    assert_equal mac.downcase, data["mac_address"]
  end

  def test_json_request_with_valid_mac
    mac = "54:ee:75:87:1f:fb"

    post "/", { mac_address: mac }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal "success", data["status"]
    # MAC addresses are normalized to lowercase
    assert_equal mac.downcase, data["mac_address"]
  end

  def test_json_request_with_charset
    mac = "54:ee:75:87:1f:fb"

    post "/", { mac_address: mac }.to_json, "CONTENT_TYPE" => "application/json; charset=utf-8"

    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal "success", data["status"]
    # MAC addresses are normalized to lowercase
    assert_equal mac.downcase, data["mac_address"]
  end

  def test_missing_mac_address
    post "/"

    assert_equal 400, last_response.status
    assert_match(/Invalid MAC address provided/, last_response.body)
  end

  def test_empty_mac_address
    post "/", :mac_address => ""

    assert_equal 400, last_response.status
    assert_match(/Invalid MAC address provided/, last_response.body)
  end

  def test_nil_mac_address
    post "/", :mac_address => nil

    assert_equal 400, last_response.status
    assert_match(/Invalid MAC address provided/, last_response.body)
  end

  def test_invalid_mac_address_too_short
    post "/", :mac_address => "54:ee:75:87:1f"

    assert_equal 400, last_response.status
    assert_match(/Invalid MAC address provided/, last_response.body)
  end

  def test_invalid_mac_address_too_long
    post "/", :mac_address => "54:ee:75:87:1f:fb:00"

    assert_equal 400, last_response.status
    assert_match(/Invalid MAC address provided/, last_response.body)
  end

  def test_invalid_mac_address_invalid_characters
    post "/", :mac_address => "54:ee:75:87:1g:fb"

    assert_equal 400, last_response.status
    assert_match(/Invalid MAC address provided/, last_response.body)
  end

  def test_invalid_mac_address_wrong_format
    post "/", :mac_address => "54ee75871ffb"

    assert_equal 400, last_response.status
    assert_match(/Invalid MAC address provided/, last_response.body)
  end

  def test_invalid_json_body
    post "/", "{ invalid json", "CONTENT_TYPE" => "application/json"

    assert_equal 415, last_response.status
    assert_match(/Invalid JSON content in body of request/, last_response.body)
  end

  def test_json_with_invalid_data_type
    post "/", "\"not a hash\"", "CONTENT_TYPE" => "application/json"

    assert_equal 415, last_response.status
    assert_match(/Invalid JSON content in body of request/, last_response.body)
  end

  def test_empty_json_body
    post "/", "", "CONTENT_TYPE" => "application/json"

    assert_equal 415, last_response.status
    assert_match(/Invalid JSON content in body of request/, last_response.body)
  end

  def test_socket_creation_error
    unstub_packet_sender
    Proxy::Wol::WolPacketSender.stubs(:send_magic_packet).raises(StandardError.new("Socket creation failed"))

    post "/", :mac_address => "54:ee:75:87:1f:fb"

    assert_equal 500, last_response.status
    assert_match(/Failed to send Wake-on-LAN packet/, last_response.body)
  end

  def test_socket_send_error
    unstub_packet_sender
    Proxy::Wol::WolPacketSender.stubs(:send_magic_packet).raises(StandardError.new("Network unreachable"))

    post "/", :mac_address => "54:ee:75:87:1f:fb"

    assert_equal 500, last_response.status
    assert_match(/Failed to send Wake-on-LAN packet/, last_response.body)
  end

  def test_response_content_type_is_json
    post "/", :mac_address => "54:ee:75:87:1f:fb"

    assert last_response.ok?
    assert_match(%r{application/json}, last_response.content_type)
  end

  def test_magic_packet_creation
    unstub_packet_sender

    mac = "54:ee:75:87:1f:fb"
    expected_mac_bytes = [0x54, 0xee, 0x75, 0x87, 0x1f, 0xfb]
    expected_magic_packet = [0xFF] * 6 + expected_mac_bytes * 16
    expected_packet = expected_magic_packet.pack('C*')

    @mock_socket.expects(:send).with(expected_packet, 0, '255.255.255.255', 9)

    post "/", :mac_address => mac

    assert last_response.ok?
  end

  def test_socket_broadcast_option
    unstub_packet_sender

    @mock_socket.expects(:setsockopt).with(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)

    post "/", :mac_address => "54:ee:75:87:1f:fb"

    assert last_response.ok?
  end

  def test_socket_close_called
    unstub_packet_sender

    @mock_socket.expects(:close)

    post "/", :mac_address => "54:ee:75:87:1f:fb"

    assert last_response.ok?
  end

  def test_mac_address_with_whitespace
    mac = " 54:ee:75:87:1f:fb "

    # Since the current implementation doesn't strip whitespace,
    # this should fail. If whitespace handling is added later,
    # this test should be updated to expect success.
    post "/", :mac_address => mac

    assert_equal 400, last_response.status
    assert_match(/Invalid MAC address provided/, last_response.body)
  end

  private

  def stub_packet_sender
    Proxy::Wol::WolPacketSender.stubs(:send_magic_packet)
  end

  def unstub_packet_sender
    Proxy::Wol::WolPacketSender.unstub(:send_magic_packet)
  end
end
