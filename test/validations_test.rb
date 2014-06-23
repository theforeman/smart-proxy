require 'test_helper'
require 'proxy/validations'

class ProxyValidationsTest < Test::Unit::TestCase
  include Proxy::Validations

  def test_should_be_valid_mac
    assert valid_mac?("aa:bb:cc:00:11:22")
    assert valid_mac?("AA:bb:CC:00:11:22")
    assert valid_mac?("aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd")
    assert valid_mac?("AA:BB:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd")
  end

  def test_should_not_be_valid_mac
    assert !valid_mac?("aa:bb:cc:00:11:zz")
    assert !valid_mac?("aa:bb:cc:00:11:22:33")
    assert !valid_mac?("aa:bb:cc:00:11")
  end

  def test_should_validate_ip
    assert_equal "192.168.1.1", validate_ip("192.168.1.1")
  end

  def test_should_not_return_invalid_ip
    assert_raise Error do
      validate_ip "192.168.1"
    end
    assert_raise Error do
      validate_ip "192.168.1.i"
    end
  end

  def test_should_validate_48bit_mac
    mac = "aa:bb:cc:00:11:22"
    mac_upcase = "AA:bb:CC:00:11:22"
    assert_equal mac, validate_mac(mac)
    assert_equal mac, validate_mac(mac_upcase)
  end

  def test_should_validate_64bit_mac
    mac = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd"
    mac_upcase = "AA:BB:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd"
    assert_equal mac, validate_mac(mac)
    assert_equal mac, validate_mac(mac_upcase)
  end

  def test_should_not_return_invalid_mac
    assert_raise Error do
      validate_mac "aa:bb:cc:00:11:22:33"
    end
    assert_raise Error do
      validate_mac "aa:bb:cc:00:11:zz"
    end
  end
end
