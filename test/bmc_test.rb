require 'test_helper'
require 'proxy/bmc/ipmi'

class BmcTest < Test::Unit::TestCase

  # Testing instructions
  #rake test TEST=test/bmc_test.rb

  def setup
    @args    = { :username => "user", :password => "pass", :bmc_provider => "ipmitool", :host => "host" }
    @bmc     = Proxy::BMC::IPMI.new(@args)
  end

  def test_creates_rubyipmi_object
    assert_not_nil bmc
  end

  def test_should_turnoff_led
      Rubyipmi::Ipmitool::Chassis.any_instance.stubs(:identify).returns(true)
      assert_equal(true, bmc.identifyoff)
  end

  def test_should_turnon_led
    Rubyipmi::Ipmitool::Chassis.any_instance.stubs(:identify).returns(true)
    assert_equal(true, bmc.identifyon)
  end

  def test_should_power_off
    Rubyipmi::Ipmitool::Power.any_instance.stubs(:off).returns(true)
    assert_equal(true, bmc.poweroff)
  end

  def test_should_power_on
    Rubyipmi::Ipmitool::Power.any_instance.stubs(:on).returns(true)
    assert_equal(true, bmc.poweron)
  end

  def test_should_power_cycle
    Rubyipmi::Ipmitool::Power.any_instance.stubs(:cycle).returns(true)
    assert_equal(true, bmc.powercycle)
  end

  def test_should_bootpxe
    Rubyipmi::Ipmitool::Chassis.any_instance.stubs(:bootpxe).returns(true)
    bmc.bootpxe
  end

  def test_should_bootdisk
    Rubyipmi::Ipmitool::Chassis.any_instance.stubs(:bootdisk).returns(true)
    bmc.bootdisk
  end

  def test_should_bootbios
    Rubyipmi::Ipmitool::Chassis.any_instance.stubs(:bootbios).returns(true)
    bmc.bootbios
  end

  def test_should_bootcdrom
    Rubyipmi::Ipmitool::Chassis.any_instance.stubs(:bootcdrom).returns(true)
    bmc.bootcdrom
  end

  private
  attr_reader :bmc

end
