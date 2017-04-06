require 'test_helper'
require 'bmc/ipmiscanner'
require 'logger'

class BmcScannerTest < Test::Unit::TestCase

  def setup
   @args = { :address_first => '192.168.1.2', :address_last => '192.168.1.7' }
   @scanner = Proxy::BMC::IPMIScanner.new(@args)
  end

  def test_create_scanner_from_combined_argument
    args = { :address => '192.168.1.0/24' }
    scanner = Proxy::BMC::IPMIScanner.new(args)
    assert(scanner.valid?)
    address_first = IPAddr.new '192.168.1.0'
    address_last  = IPAddr.new '192.168.1.255'
    assert_equal(scanner.instance_variable_get(:@range), (address_first..address_last))
  end

  def test_create_scanner_from_address_and_prefixlen
    args = { :address => '192.168.1.0', :netmask => '24' }
    scanner = Proxy::BMC::IPMIScanner.new(args)
    assert(scanner.valid?)
    address_first = IPAddr.new '192.168.1.0'
    address_last  = IPAddr.new '192.168.1.255'
    assert_equal(scanner.instance_variable_get(:@range), (address_first..address_last))
  end

  def test_create_scanner_from_address_and_netmask
    args = { :address => '192.168.1.0', :netmask => '255.255.255.0' }
    scanner = Proxy::BMC::IPMIScanner.new(args)
    assert(scanner.valid?)
    address_first = IPAddr.new '192.168.1.0'
    address_last  = IPAddr.new '192.168.1.255'
    assert_equal(scanner.instance_variable_get(:@range), (address_first..address_last))
  end

  def test_create_scanner_from_range
    args = { :address_first => '192.168.1.0', :address_last => '192.168.1.255' }
    scanner = Proxy::BMC::IPMIScanner.new(args)
    assert(scanner.valid?)
    address_first = IPAddr.new '192.168.1.0'
    address_last  = IPAddr.new '192.168.1.255'
    assert_equal(scanner.instance_variable_get(:@range), (address_first..address_last))
  end

  def test_fail_create_scanner_from_invalid_argument
    scanner = Proxy::BMC::IPMIScanner.new('bogus')
    assert !scanner.valid?
    assert scanner.instance_variable_get(:@range).nil?
  end

  def test_fail_create_scanner_when_range_too_large_with_default_max_range_size
    Proxy::BMC::Plugin.settings.expects(:bmc_scanner_max_range_size).returns(nil)
    args = { :address_first => '15.0.0.0', :address_last => '16.255.255.255' }
    scanner = Proxy::BMC::IPMIScanner.new(args)
    assert !scanner.valid?
    assert scanner.instance_variable_get(:@range).nil?
  end

  def test_fail_create_scanner_when_range_too_large_with_custom_max_range_size
    Proxy::BMC::Plugin.settings.expects(:bmc_scanner_max_range_size).returns(8)
    args = { :address_first => '15.0.0.0', :address_last => '15.0.0.9' }
    scanner = Proxy::BMC::IPMIScanner.new(args)
    assert !scanner.valid?
    assert scanner.instance_variable_get(:@range).nil?
  end

  def test_fail_scan_when_scanner_not_valid
    scanner = Proxy::BMC::IPMIScanner.new('bogus')
    assert !scanner.valid?
    assert !scanner.scan_to_list
  end

  def test_address_pings
    mock_socket = mock()
    mock_socket.expects(:connect).returns(true)
    mock_socket.expects(:send).returns(nil)
    mock_socket.expects(:close).returns(true)
    UDPSocket.stubs(:new).returns(mock_socket)
    IO.expects(:select).returns([mock_socket, nil, nil])
    assert @scanner.address_pings?('192.168.1.2')
  end

  def test_address_does_not_ping
    mock_socket = mock()
    mock_socket.expects(:connect).returns(true)
    mock_socket.expects(:send).returns(nil)
    mock_socket.expects(:close).returns(true)
    UDPSocket.stubs(:new).returns(mock_socket)
    IO.expects(:select).returns(nil)
    assert !@scanner.address_pings?('192.168.1.2')
  end

  def test_default_socket_timeout_in_address_ping
    expected = 1
    Proxy::BMC::Plugin.settings.stubs(:bmc_scanner_socket_timeout_seconds).returns(nil)
    mock_socket = mock()
    mock_socket.expects(:connect).returns(true)
    mock_socket.expects(:send).returns(nil)
    mock_socket.expects(:close).returns(true)
    UDPSocket.stubs(:new).returns(mock_socket)
    IO.expects(:select).with{|read, write, error, timeout| timeout == expected }.returns([mock_socket, nil, nil])
    assert @scanner.address_pings?('192.168.1.2')
  end

  def test_custom_socket_timeout_in_address_ping
    expected = 3
    Proxy::BMC::Plugin.settings.stubs(:bmc_scanner_socket_timeout_seconds).returns(expected)
    mock_socket = mock()
    mock_socket.expects(:connect).returns(true)
    mock_socket.expects(:send).returns(nil)
    mock_socket.expects(:close).returns(true)
    UDPSocket.stubs(:new).returns(mock_socket)
    IO.expects(:select).with{|read, write, error, timeout| timeout == expected }.returns([mock_socket, nil, nil])
    assert @scanner.address_pings?('192.168.1.2')
  end

  def test_default_number_of_max_threads
    Proxy::BMC::Plugin.settings.stubs(:bmc_scanner_max_threads_per_request).returns(nil)
    mock_socket = mock()
    UDPSocket.stubs(:new).returns(mock_socket)
    result = @scanner.calculate_max_threads
    assert_equal(result, 500)
  end

  def test_custom_number_of_max_threads
    Proxy::BMC::Plugin.settings.stubs(:bmc_scanner_max_threads_per_request).returns(418)
    mock_socket = mock()
    UDPSocket.stubs(:new).returns(mock_socket)
    result = @scanner.calculate_max_threads
    assert_equal(result, 418)
  end

  def test_half_number_of_500_max_threads_when_large_range
    remaining_sockets =     [1, 2, 5, 10, 25, 100, 250, 499, 500, 750, 1000]
    expected_sockets_used = [1, 1, 2,  5, 12,  50, 125, 249, 500, 500,  500]
    args = { :address => '15.0.0.0/16' }
    Proxy::BMC::Plugin.settings.expects(:bmc_scanner_max_range_size).returns(65_536)
    Proxy::BMC::Plugin.settings.stubs(:bmc_scanner_max_threads_per_request).returns(500)
    scanner = Proxy::BMC::IPMIScanner.new(args)
    assert scanner.valid?
    mock_socket = mock()
    mock_socket.stubs(:close).returns(true)
    for i in 0..(remaining_sockets.size-1)
      UDPSocket.stubs(:new).returns(*[mock_socket] * remaining_sockets[i]).then.raises(Errno::EMFILE)
      result = scanner.calculate_max_threads
      assert_equal(result, expected_sockets_used[i])
    end
  end

  def test_half_number_of_245_max_threads_when_large_range
    remaining_sockets =     [1, 2, 5, 10, 25, 100, 243, 244, 245, 500]
    expected_sockets_used = [1, 1, 2,  5, 12,  50, 121, 122, 245, 245]
    args = { :address => '16.0.0.0/16' }
    Proxy::BMC::Plugin.settings.expects(:bmc_scanner_max_range_size).returns(65_536)
    Proxy::BMC::Plugin.settings.stubs(:bmc_scanner_max_threads_per_request).returns(245)
    scanner = Proxy::BMC::IPMIScanner.new(args)
    assert scanner.valid?
    mock_socket = mock()
    mock_socket.stubs(:close).returns(true)
    for i in 0..(remaining_sockets.size-1)
      UDPSocket.stubs(:new).returns(*[mock_socket] * remaining_sockets[i]).then.raises(Errno::EMFILE)
      result = scanner.calculate_max_threads
      assert_equal(result, expected_sockets_used[i])
    end
  end

  def test_should_scan_to_list
    expected = ['192.168.1.3', '192.168.1.5', '192.168.1.6']
    Proxy::BMC::IPMIScanner.any_instance.expects(:address_pings?).with(){|address| address == '192.168.1.2'}.returns(false)
    Proxy::BMC::IPMIScanner.any_instance.expects(:address_pings?).with(){|address| address == '192.168.1.3'}.returns(true)
    Proxy::BMC::IPMIScanner.any_instance.expects(:address_pings?).with(){|address| address == '192.168.1.4'}.returns(false)
    Proxy::BMC::IPMIScanner.any_instance.expects(:address_pings?).with(){|address| address == '192.168.1.5'}.returns(true)
    Proxy::BMC::IPMIScanner.any_instance.expects(:address_pings?).with(){|address| address == '192.168.1.6'}.returns(true)
    Proxy::BMC::IPMIScanner.any_instance.expects(:address_pings?).with(){|address| address == '192.168.1.7'}.returns(false)
    result = @scanner.scan_to_list
    assert_equal(expected.length, result.length)
    expected.each do |address|
      assert_send([result, :include?, address])
    end
  end

  def test_should_scan_to_list_unthreaded
    expected = ['192.168.1.3', '192.168.1.5', '192.168.1.6']
    Proxy::BMC::IPMIScanner.any_instance.stubs(:address_pings?).returns(false, true, false, true, true, false)
    result = @scanner.scan_unthreaded_to_list
    assert_equal(expected.length, result.length)
    expected.each do |address|
      assert_send([result, :include?, address])
    end
  end
end

