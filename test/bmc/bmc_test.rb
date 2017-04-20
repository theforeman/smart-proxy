require 'test_helper'
require 'bmc/ipmi'
require 'logger'

class BmcTest < Test::Unit::TestCase

  def setup
    @args = { :username => "user", :password => "pass", :bmc_provider => "ipmitool", :host => "host" }
    @bmc  = Proxy::BMC::IPMI.new(@args)
  end

  def test_sets_logger
    log = Logger.new('/tmp/logtest.log')
    log.level = Logger::INFO
    Proxy::BMC::IPMI.logger = log
    assert_equal log, Proxy::BMC::IPMI.logger
  end

  def test_creates_rubyipmi_object
    assert_not_nil bmc
  end

  def test_should_run_connection_test
    Rubyipmi::Ipmitool::Connection.any_instance.expects(:connection_works?).returns(true)
    assert bmc.test
    Rubyipmi::Ipmitool::Connection.any_instance.expects(:connection_works?).returns(false)
    assert !bmc.test
  end

  def test_should_turnoff_led
    Rubyipmi::Ipmitool::Chassis.any_instance.expects(:identify).returns(true)
    assert bmc.identifyoff
  end

  def test_should_turnon_led
    Rubyipmi::Ipmitool::Chassis.any_instance.expects(:identify).returns(true)
    assert bmc.identifyon
  end

  def test_should_power_off
    Rubyipmi::Ipmitool::Power.any_instance.expects(:off).returns(true)
    assert bmc.poweroff
  end

  def test_should_power_on
    Rubyipmi::Ipmitool::Power.any_instance.expects(:on).returns(true)
    assert bmc.poweron
  end

  def test_should_power_cycle
    Rubyipmi::Ipmitool::Power.any_instance.expects(:cycle).returns(true)
    assert bmc.powercycle
  end

  def test_should_power_reset
    Rubyipmi::Ipmitool::Power.any_instance.expects(:reset).returns(true)
    assert bmc.powerreset
  end

  def test_should_bootpxe
    Rubyipmi::Ipmitool::Chassis.any_instance.expects(:bootpxe).returns(true)
    bmc.bootpxe
  end

  def test_should_bootdisk
    Rubyipmi::Ipmitool::Chassis.any_instance.expects(:bootdisk).returns(true)
    bmc.bootdisk
  end

  def test_should_bootbios
    Rubyipmi::Ipmitool::Chassis.any_instance.expects(:bootbios).returns(true)
    bmc.bootbios
  end

  def test_should_bootcdrom
    Rubyipmi::Ipmitool::Chassis.any_instance.expects(:bootcdrom).returns(true)
    bmc.bootcdrom
  end

  def test_should_ip
    Rubyipmi::Ipmitool::Lan.any_instance.expects(:ip).returns(true)
    bmc.ip
  end

  def test_should_mac
    Rubyipmi::Ipmitool::Lan.any_instance.expects(:mac).returns(true)
    bmc.mac
  end

  def test_should_gateway
    Rubyipmi::Ipmitool::Lan.any_instance.expects(:gateway).returns(true)
    bmc.gateway
  end

  def test_should_netmask
    Rubyipmi::Ipmitool::Lan.any_instance.expects(:netmask).returns(true)
    bmc.netmask
  end

  def test_should_snmp
    Rubyipmi::Ipmitool::Lan.any_instance.expects(:snmp).returns(true)
    bmc.snmp
  end

  def test_should_vlanid
    Rubyipmi::Ipmitool::Lan.any_instance.expects(:vlanid).returns(true)
    bmc.vlanid
  end

  def test_ipsrc_true
    Rubyipmi::Ipmitool::Lan.any_instance.expects(:dhcp?).returns(true)
    assert_equal bmc.ipsrc, "dhcp"
  end

  def test_ipsrc_false
    Rubyipmi::Ipmitool::Lan.any_instance.expects(:dhcp?).returns(false)
    assert_equal bmc.ipsrc, "static"
  end

  def test_should_lanprint
    Rubyipmi::Ipmitool::Lan.any_instance.expects(:info).returns(true)
    bmc.lanprint
  end

  def test_should_info
    Rubyipmi::Ipmitool::Bmc.any_instance.expects(:info).returns(true)
    bmc.info
  end

  def test_should_guid
    Rubyipmi::Ipmitool::Bmc.any_instance.expects(:guid).returns(true)
    bmc.guid
  end

  def test_should_version
    Rubyipmi::Ipmitool::Bmc.any_instance.expects(:version).returns(true)
    bmc.version
  end

  def test_should_reset_default
    Rubyipmi::Ipmitool::Bmc.any_instance.expects(:reset).with('cold').returns(true)
    bmc.reset
  end

  def test_should_reset_cold
    Rubyipmi::Ipmitool::Bmc.any_instance.expects(:reset).with('cold').returns(true)
    bmc.reset('cold')
  end

  def test_should_reset_warm
    Rubyipmi::Ipmitool::Bmc.any_instance.expects(:reset).with('warm').returns(true)
    bmc.reset('warm')
  end

  def test_should_frulist
    Rubyipmi::Ipmitool::Fru.any_instance.expects(:list).returns(true)
    bmc.frulist
  end

  def test_frulist_2xquirk_freeipmi
    Rubyipmi::Freeipmi::Fru.any_instance.expects(:list).times(2).raises(StandardError).then.returns(true)
    args = { :username => "user", :password => "pass", :bmc_provider => "freeipmi", :host => "host" }
    bmc  = Proxy::BMC::IPMI.new(args)
    assert_equal bmc.frulist, true
  end

  def test_frulist_2xquirk_ipmitool
    Rubyipmi::Ipmitool::Fru.any_instance.expects(:list).times(1).returns({})
    args = { :username => "user", :password => "pass", :bmc_provider => "ipmitool", :host => "host" }
    bmc  = Proxy::BMC::IPMI.new(args)
    assert_equal bmc.frulist, "Unknown error getting fru list. Try bmc_provider=freeipmi for possible quirk workaround."
  end

  def test_frulist_2xquirk_fail
    Rubyipmi::Freeipmi::Fru.any_instance.expects(:list).times(2).raises(StandardError)
    args = { :username => "user", :password => "pass", :bmc_provider => "freeipmi", :host => "host" }
    bmc  = Proxy::BMC::IPMI.new(args)
    assert_equal bmc.frulist, "Error getting fru list: StandardError"
  end

  def test_frulist_fail_ipmitool
    Rubyipmi::Ipmitool::Fru.any_instance.expects(:list).times(1).raises(StandardError)
    assert_equal bmc.frulist, "Error getting fru list: StandardError"
  end

  def test_should_manufacturer
    Rubyipmi::Ipmitool::Fru.any_instance.expects(:manufacturer).returns(true)
    bmc.manufacturer
  end

  def test_should_model
    Rubyipmi::Ipmitool::Fru.any_instance.expects(:product_name).returns(true)
    bmc.model
  end

  def test_should_serial
    Rubyipmi::Ipmitool::Fru.any_instance.expects(:product_serial).returns(true)
    bmc.serial
  end

  def test_should_asset_tag
    Rubyipmi::Ipmitool::Fru.any_instance.expects(:product_asset_tag).returns(true)
    bmc.asset_tag
  end

  def test_should_sensorlist
    Rubyipmi::Ipmitool::Sensors.any_instance.expects(:list).returns(true)
    bmc.sensorlist
  end

  def test_should_sensorcount
    Rubyipmi::Ipmitool::Sensors.any_instance.expects(:count).returns(true)
    bmc.sensorcount
  end

  def test_should_sensornames
    Rubyipmi::Ipmitool::Sensors.any_instance.expects(:names).returns(true)
    bmc.sensornames
  end

  def test_should_fanlist
    Rubyipmi::Ipmitool::Sensors.any_instance.expects(:fanlist).returns(true)
    bmc.fanlist
  end

  def test_should_templist
    Rubyipmi::Ipmitool::Sensors.any_instance.expects(:templist).returns(true)
    bmc.templist
  end

  def test_should_sensorget
    Rubyipmi::Ipmitool::Sensors.any_instance.expects(:list).returns(true)
    bmc.sensorget('anything')
  end

  def test_sensorget
    Rubyipmi::Ipmitool::Sensors.any_instance.expects(:list).returns('test_sensor' => {'key' => 'value'}, 'not_my_sensor' => {'foo' => 'bar'})
    assert_equal({'key' => 'value'}, bmc.sensorget('test_sensor'))
  end

  private
  attr_reader :bmc

end
