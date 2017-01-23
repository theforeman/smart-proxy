require 'test_helper'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/record'
require 'dhcp_common/subnet'
require 'dhcp_common/record/reservation'
require 'dhcp_common/record/deleted_reservation'
require 'dhcp_common/record/lease'

class Proxy::DHCPRecordTest < Test::Unit::TestCase

  def setup
    @subnet = Proxy::DHCP::Subnet.new("192.168.0.0","255.255.255.0")
    @ip = "123.321.123.321"
    @mac = "aa:bb:CC:dd:ee:ff"
    @record = Proxy::DHCP::Record.new(@ip, @mac, @subnet)
  end

  def test_record_should_have_a_subnet
    assert_kind_of Proxy::DHCP::Subnet, @record.subnet
  end

  def test_should_convert_to_string
    ip = "1.1.1.1"
    mac = "aa:bb:cc:dd:ea:ff"
    assert_equal Proxy::DHCP::Record.new(ip, mac, @subnet).to_s, "#{ip} / #{mac}"
  end

  def test_should_not_save_invalid_ip_addresses
    ip = "1..1.1"
    assert_raise(Proxy::Validations::Error) { Proxy::DHCP::Record.new(ip, @mac, @subnet) }
  end

  def test_mac_should_be_saved_lower_case
    mac = "AA:BB:CC:DD:EE:aF"
    ip = "192.168.0.12"
    assert_equal Proxy::DHCP::Record.new(ip, mac, @subnet).mac, mac.downcase
  end

  def test_should_not_save_invalid_mac
    assert_raise(Proxy::Validations::Error) { Proxy::DHCP::Record.new(@ip, "XYZxxVVcc123", @subnet) }
  end

  def test_should_not_save_invalid_subnets
    assert_raise(Proxy::Validations::Error) { Proxy::DHCP::Record.new(@ip, @mac, nil) }
  end

  def test_equality
    assert_equal Proxy::DHCP::Record.new(@ip, @mac, Proxy::DHCP::Subnet.new("192.168.0.0","255.255.255.0"), :option1 => 'one'),
                 Proxy::DHCP::Record.new(@ip, @mac, Proxy::DHCP::Subnet.new("192.168.0.0","255.255.255.0"), :option1 => 'one')
    assert_not_equal Proxy::DHCP::Record.new(@ip, @mac, @subnet, :option1 => 'one'),
                     Proxy::DHCP::Record.new('1.1.1.1', @mac, @subnet, :option1 => 'one')
    assert_not_equal Proxy::DHCP::Record.new(@ip, @mac, @subnet, :option1 => 'one'),
                     Proxy::DHCP::Record.new(@ip, '00:01:02:03:04:05', @subnet, :option1 => 'one')
    assert_not_equal Proxy::DHCP::Record.new(@ip, @mac, @subnet, :option1 => 'one'),
                     Proxy::DHCP::Record.new(@ip, @mac, @subnet, :option2 => 'two')
    assert_not_equal Proxy::DHCP::Record.new(@ip, @mac, @subnet, :option1 => 'one'),
                     Proxy::DHCP::Record.new(@ip, @mac, ::Proxy::DHCP::Subnet.new("192.168.0.0","255.255.255.128"), :option1 => 'one')
  end

  def test_reservation_equality
    assert_equal Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option1 => 'one'),
                 Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option1 => 'one')
    assert_not_equal Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option1 => 'one'), nil
    assert_not_equal Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option1 => 'one'), Object.new
    assert_not_equal Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option1 => 'one'),
                     Proxy::DHCP::Reservation.new('test-another', @ip, @mac, @subnet, :option1 => 'one')
    assert_not_equal Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option1 => 'one'),
                     Proxy::DHCP::Reservation.new('test', '1.1.1.1', @mac, @subnet, :option1 => 'one')
    assert_not_equal Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option1 => 'one'),
                     Proxy::DHCP::Reservation.new('test', @ip, '00:01:02:03:04:05', @subnet, :option1 => 'one')
    assert_not_equal Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option1 => 'one'),
                     Proxy::DHCP::Reservation.new('test', @ip, @mac, ::Proxy::DHCP::Subnet.new("192.168.0.0","255.255.255.128"), :option1 => 'one')
    assert_not_equal Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option1 => 'one'),
                     Proxy::DHCP::Reservation.new('test', @ip, @mac, @subnet, :option2 => 'one')
  end

  def test_deleted_reservation_equality
    assert_equal Proxy::DHCP::DeletedReservation.new('test'), Proxy::DHCP::DeletedReservation.new('test')
    assert_not_equal Proxy::DHCP::DeletedReservation.new('test'), nil
    assert_not_equal Proxy::DHCP::DeletedReservation.new('test'), Object.new
    assert_not_equal Proxy::DHCP::DeletedReservation.new('test'), Proxy::DHCP::DeletedReservation.new('test-1')
  end

  def test_lease_equality
    start_time = Time.now
    end_time = Time.now + 10

    assert_equal Proxy::DHCP::Lease.new('lease', @ip, @mac, Proxy::DHCP::Subnet.new("192.168.0.0","255.255.255.0"), start_time, end_time, 'active', :option1 => 'one'),
                 Proxy::DHCP::Lease.new('lease', @ip, @mac, Proxy::DHCP::Subnet.new("192.168.0.0","255.255.255.0"), start_time, end_time, 'active', :option1 => 'one')
    assert_not_equal Proxy::DHCP::Lease.new('lease', @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one'), Object.new
    assert_not_equal Proxy::DHCP::Lease.new('lease', @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one'),
                     Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one')
    assert_not_equal Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one'),
                     Proxy::DHCP::Lease.new(nil, '1.1.1.1', @mac, @subnet, start_time, end_time, 'active', :option1 => 'one')
    assert_not_equal Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one'),
                     Proxy::DHCP::Lease.new(nil, @ip, '00:01:02:03:04:05', @subnet, start_time, end_time, 'active', :option1 => 'one')
    assert_not_equal Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one'),
                     Proxy::DHCP::Lease.new(nil, @ip, @mac, ::Proxy::DHCP::Subnet.new("192.168.0.0","255.255.255.128"), start_time, end_time, 'active', :option1 => 'one')
    assert_not_equal Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one'),
                     Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time + 5, end_time, 'active', :option1 => 'one')
    assert_not_equal Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one'),
                     Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time + 5, 'active', :option1 => 'one')
    assert_not_equal Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one'),
                     Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'free', :option1 => 'one')
    assert_not_equal Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'active', :option1 => 'one'),
                     Proxy::DHCP::Lease.new(nil, @ip, @mac, @subnet, start_time, end_time, 'active', :option2 => 'two')
  end
end
