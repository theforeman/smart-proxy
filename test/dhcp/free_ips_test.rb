require 'test_helper'
require 'set'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/subnet'
require 'dhcp_common/record/reservation'
require 'dhcp_common/free_ips'

class Proxy::DHCPFreeIpsTest < Test::Unit::TestCase
  def setup
    @blacklist_interval = 30 * 60
    @free_ips = Proxy::DHCP::FreeIps.new(@blacklist_interval)
    @subnet = Proxy::DHCP::Subnet.new("192.168.1.0", "255.255.255.0")
  end

  def test_random_index
    indices = Set.new
    @free_ips.random_index(6) { |i| indices << i }
    assert_equal 6, indices.size
    assert_equal Set.new([0, 1, 2, 3, 4, 5]), indices
  end

  def test_random_index_for_array_of_size_one
    indices = Set.new
    @free_ips.random_index(1) { |i| indices << i }
    assert_equal Set.new([0]), indices
  end

  def test_address_range_with_start_and_end
    assert_equal [3_232_235_620, 100], @free_ips.address_range_with_start_and_end("192.168.0.100", "192.168.0.200")
  end

  def test_find_free_ip
    @free_ips.stubs(:icmp_pingable?).returns(false)
    @free_ips.stubs(:tcp_pingable?).returns(false)
    r = Proxy::DHCP::Reservation.new('test', "192.168.1.1", "aa:bb:cc:dd:ee:ff", @subnet, :hostname => 'test')

    assert_equal "192.168.1.2", @free_ips.find_free_ip("192.168.1.1", "192.168.1.2", [r])
  end

  def test_find_free_ip_should_return_nil_when_no_addresses_available
    @free_ips.stubs(:icmp_pingable?).returns(false)
    @free_ips.stubs(:tcp_pingable?).returns(false)
    r = Proxy::DHCP::Reservation.new('test', "192.168.1.1", "aa:bb:cc:dd:ee:ff", @subnet, :hostname => 'test')

    assert_nil @free_ips.find_free_ip("192.168.1.1", "192.168.1.1", [r])
  end

  def test_find_free_ip_should_return_nil_when_whole_pool_is_blacklisted
    @free_ips.mark_ip_as_allocated("192.168.1.1")
    @free_ips.mark_ip_as_allocated("192.168.1.2")
    assert_nil @free_ips.find_free_ip("192.168.1.1", "192.168.1.2", [])
  end

  def test_find_free_ip_should_temprarily_blacklist_allocated_ip
    @free_ips.stubs(:icmp_pingable?).returns(false)
    @free_ips.stubs(:tcp_pingable?).returns(false)
    @free_ips.expects(:time_now).returns(time_now = Time.now.to_i)
    r = Proxy::DHCP::Reservation.new('test', "192.168.1.1", "aa:bb:cc:dd:ee:ff", @subnet, :hostname => 'test')

    assert @free_ips.allocated_ips.empty?
    assert @free_ips.allocation_timestamps.empty?

    @free_ips.find_free_ip("192.168.1.1", "192.168.1.2", [r])

    assert @free_ips.allocated_ips.include?("192.168.1.2")
    assert @free_ips.allocation_timestamps.include?(["192.168.1.2", time_now + @blacklist_interval])
  end

  def test_find_free_ip_should_use_icmp_ping
    @free_ips.expects(:icmp_pingable?).returns(false)
    @free_ips.stubs(:tcp_pingable?).returns(false)
    r = Proxy::DHCP::Reservation.new('test', "192.168.1.1", "aa:bb:cc:dd:ee:ff", @subnet, :hostname => 'test')
    @free_ips.find_free_ip("192.168.1.1", "192.168.1.2", [r])
  end

  def test_find_free_ip_should_use_tcp_ping
    @free_ips.expects(:tcp_pingable?).returns(false)
    @free_ips.stubs(:icmp_pingable?).returns(false)
    r = Proxy::DHCP::Reservation.new('test', "192.168.1.1", "aa:bb:cc:dd:ee:ff", @subnet, :hostname => 'test')
    @free_ips.find_free_ip("192.168.1.1", "192.168.1.2", [r])
  end

  def test_find_free_ip_should_temporarily_blaclist_pingable_ip
    @free_ips.expects(:tcp_pingable?).returns(true)
    @free_ips.stubs(:icmp_pingable?).returns(false)
    @free_ips.expects(:time_now).returns(time_now = Time.now.to_i)
    r = Proxy::DHCP::Reservation.new('test', "192.168.1.1", "aa:bb:cc:dd:ee:ff", @subnet, :hostname => 'test')

    assert @free_ips.allocated_ips.empty?
    assert @free_ips.allocation_timestamps.empty?

    @free_ips.find_free_ip("192.168.1.1", "192.168.1.2", [r])

    assert @free_ips.allocated_ips.include?("192.168.1.2")
    assert @free_ips.allocation_timestamps.include?(["192.168.1.2", time_now + @blacklist_interval])
  end

  def test_clean_up_allocated_ips
    @free_ips.stubs(:icmp_pingable?).returns(false)
    @free_ips.stubs(:tcp_pingable?).returns(false)
    @free_ips.expects(:time_now).returns(Time.now.to_i)
    r = Proxy::DHCP::Reservation.new('test', "192.168.1.1", "aa:bb:cc:dd:ee:ff", @subnet, :hostname => 'test')

    @free_ips.find_free_ip("192.168.1.1", "192.168.1.2", [r])

    assert_false @free_ips.allocated_ips.empty?
    assert_false @free_ips.allocation_timestamps.empty?

    @free_ips.expects(:time_now).returns(Time.now.to_i + @blacklist_interval + 10)
    @free_ips.clean_up_allocated_ips

    assert @free_ips.allocated_ips.empty?
    assert @free_ips.allocation_timestamps.empty?
  end
end
