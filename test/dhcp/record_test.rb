require 'test_helper'

require 'dhcp/dhcp'
require 'dhcp/server'
require 'dhcp/subnet'
require 'dhcp/record'

class Proxy::DHCPRecordTest < Test::Unit::TestCase

  def setup
    @subnet = Proxy::DHCP::Subnet.new("192.168.0.0","255.255.255.0")
    @ip = "123.321.123.321"
    @mac = "aa:bb:CC:dd:ee:ff"
    @record = Proxy::DHCP::Record.new(:subnet => @subnet, :ip => @ip, :mac => @mac)
  end

  def test_record_should_have_a_subnet
    assert_kind_of Proxy::DHCP::Subnet, @record.subnet
  end

  def test_should_return_a_record_kind
    assert_equal @record.kind, "record"
  end

  def test_should_convert_to_string
    ip = "1.1.1.1"
    mac = "aa:bb:cc:dd:ea:ff"
    assert_equal Proxy::DHCP::Record.new(:subnet => @subnet, :ip => ip, :mac => mac).to_s, "#{ip} / #{mac}"
  end

  def test_should_have_a_logger
    assert_respond_to @record, :logger
  end

  def test_should_not_save_invalid_ip_addresses
    ip = "1..1.1"
    assert_raise Proxy::Validations::Error do
      Proxy::DHCP::Record.new(:subnet => @subnet, :ip => ip,  :mac => @mac)
    end
  end

  def test_mac_should_be_saved_lower_case
    mac = "AA:BB:CC:DD:EE:aF"
    ip = "192.168.0.12"
    assert_equal Proxy::DHCP::Record.new(:subnet => @subnet, :ip => ip, :mac => mac).mac, mac.downcase
  end

  def test_should_not_save_invalid_mac
    mac = "XYZxxVVcc123"
    assert_raise Proxy::Validations::Error do
      Proxy::DHCP::Record.new(:subnet => @subnet, :ip => @ip, :mac => mac)
    end
  end

  def test_should_not_save_invalid_subnets
    subnet = nil
    assert_raise Proxy::Validations::Error do
      Proxy::DHCP::Record.new(:subnet => subnet, :ip => @ip, :mac => @mac)
    end
  end

  def test_options_should_be_a_hash
    assert_kind_of Hash, @record.options
  end
end
