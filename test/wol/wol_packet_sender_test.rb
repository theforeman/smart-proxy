require 'test_helper'
require 'wol/wol_packet_sender'

class WolPacketSenderTest < Test::Unit::TestCase
  def setup
    # Mock UDPSocket to prevent actual network packets during tests
    @mock_socket = mock('UDPSocket')
    UDPSocket.stubs(:new).returns(@mock_socket)
    @mock_socket.stubs(:setsockopt)
    @mock_socket.stubs(:send)
    @mock_socket.stubs(:close)
  end

  def test_create_magic_packet_structure
    mac = "54:ee:75:87:1f:fb"
    packet = Proxy::Wol::WolPacketSender.create_magic_packet(mac)

    # Expected packet structure: 6 bytes of 0xFF followed by 16 repetitions of MAC
    expected_mac_bytes = [0x54, 0xee, 0x75, 0x87, 0x1f, 0xfb]
    expected_magic_packet = [0xFF] * 6 + expected_mac_bytes * 16
    expected_packet = expected_magic_packet.pack('C*')

    assert_equal expected_packet, packet
  end

  def test_magic_packet_length
    # A WoL magic packet should be exactly 102 bytes
    # 6 bytes of 0xFF + (6 bytes MAC × 16 repetitions) = 6 + 96 = 102 bytes
    mac = "54:ee:75:87:1f:fb"
    packet = Proxy::Wol::WolPacketSender.create_magic_packet(mac)

    assert_equal 102, packet.length
  end

  def test_magic_packet_starts_with_sync_bytes
    mac = "AA:BB:CC:DD:EE:FF"
    packet = Proxy::Wol::WolPacketSender.create_magic_packet(mac)

    # First 6 bytes should all be 0xFF
    sync_bytes = packet[0..5].unpack('C*')
    assert_equal [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF], sync_bytes
  end

  def test_magic_packet_contains_mac_repetitions
    mac = "12:34:56:78:9A:BC"
    packet = Proxy::Wol::WolPacketSender.create_magic_packet(mac)

    # Extract MAC repetitions (skip first 6 sync bytes)
    mac_section = packet[6..]
    mac_bytes = mac_section.unpack('C*')

    # Should contain exactly 16 repetitions of the MAC address
    expected_mac = [0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC]
    expected_repetitions = expected_mac * 16

    assert_equal expected_repetitions, mac_bytes
  end

  def test_magic_packet_different_macs_produce_different_packets
    mac1 = "AA:BB:CC:DD:EE:FF"
    mac2 = "11:22:33:44:55:66"

    packet1 = Proxy::Wol::WolPacketSender.create_magic_packet(mac1)
    packet2 = Proxy::Wol::WolPacketSender.create_magic_packet(mac2)

    refute_equal packet1, packet2
  end

  def test_send_magic_packet_uses_correct_socket_options
    mac = "54:ee:75:87:1f:fb"

    # Verify that broadcast is enabled on the socket
    @mock_socket.expects(:setsockopt).with(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)

    Proxy::Wol::WolPacketSender.send_magic_packet(mac)
  end

  def test_send_magic_packet_sends_to_broadcast_address
    mac = "54:ee:75:87:1f:fb"

    # Verify that packet is sent to broadcast address on port 9
    @mock_socket.expects(:send).with(anything, 0, '255.255.255.255', 9)

    Proxy::Wol::WolPacketSender.send_magic_packet(mac)
  end

  def test_send_magic_packet_sends_correct_packet
    mac = "54:ee:75:87:1f:fb"
    expected_packet = Proxy::Wol::WolPacketSender.create_magic_packet(mac)

    @mock_socket.expects(:send).with(expected_packet, 0, '255.255.255.255', 9)

    Proxy::Wol::WolPacketSender.send_magic_packet(mac)
  end

  def test_send_magic_packet_closes_socket
    mac = "54:ee:75:87:1f:fb"

    @mock_socket.expects(:close)

    Proxy::Wol::WolPacketSender.send_magic_packet(mac)
  end

  def test_send_magic_packet_handles_send_error
    @mock_socket.stubs(:send).raises(StandardError.new("Network unreachable"))

    assert_raises(StandardError) do
      Proxy::Wol::WolPacketSender.send_magic_packet("54:ee:75:87:1f:fb")
    end
  end

  def test_create_magic_packet_uppercase_mac
    mac = "AA:BB:CC:DD:EE:FF"
    packet = Proxy::Wol::WolPacketSender.create_magic_packet(mac)

    # Extract the first MAC repetition after sync bytes
    first_mac = packet[6..11].unpack('C*')
    expected_mac = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]

    assert_equal expected_mac, first_mac
  end

  def test_create_magic_packet_lowercase_mac
    mac = "aa:bb:cc:dd:ee:ff"
    packet = Proxy::Wol::WolPacketSender.create_magic_packet(mac)

    # Extract the first MAC repetition after sync bytes
    first_mac = packet[6..11].unpack('C*')
    expected_mac = [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]

    assert_equal expected_mac, first_mac
  end
end
