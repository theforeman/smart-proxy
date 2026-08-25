require 'test_helper'
require 'bmc/bmc_plugin'
require 'bmc/redfish'
require 'bmc/redfish_test_helper'
require 'json'

class BmcRedfishTest < Minitest::Test
  include RedfishTestHelper

  def setup
    @host = "host"
    @protocol = "https"
    mask_redfish_acceess(protocol: @protocol, host: @host)
    @args = { :username => "user", :password => "pass", :host => @host }
    @bmc  = Proxy::BMC::Redfish.new(@args)
  end

  def test_redfish_provider_cycle
    stub_request(:post, "#{@protocol}://#{@host}#{SYSTEM_DATA['Actions']['#ComputerSystem.Reset']['target']}").
      with(body: JSON.generate({"ResetType" => "PowerCycle"})).
      to_return(status: 200, body: JSON.generate({}))
    assert @bmc.powercycle
  end

  def test_redfish_provider_reset
    stub_request(:post, "#{@protocol}://#{@host}#{SYSTEM_DATA['Actions']['#ComputerSystem.Reset']['target']}").
      with(body: JSON.generate({"ResetType" => "ForceRestart"})).
      to_return(status: 200, body: JSON.generate({}))
    assert @bmc.powerreset
  end

  def test_redfish_provider_reboot
    stub_request(:post, "#{@protocol}://#{@host}#{SYSTEM_DATA['Actions']['#ComputerSystem.Reset']['target']}").
      with(body: JSON.generate({ "ResetType" => "GracefulRestart" })).
      to_return(status: 200, body: JSON.generate({}))
    assert @bmc.powerreboot
  end

  def test_bootdevice_pxe_uses_patch_if_match
    # Test that bootdevice uses patch_if_match for PXE boot
    system_mock = mock('system')

    system_mock.expects(:patch_if_match).with(
      {
        'Boot' => {
          'BootSourceOverrideTarget' => 'Pxe',
          'BootSourceOverrideEnabled' => 'Once',
        },
      }
    ).returns(true)

    @bmc.expects(:system).returns(system_mock)
    @bmc.expects(:powercycle).never

    result = @bmc.bootdevice = { :device => 'pxe', :reboot => false, :persistent => false }
    refute_nil result
  end

  def test_bootdevice_disk_persistent_uses_patch_if_match
    # Test that bootdevice uses patch_if_match with persistent boot
    system_mock = mock('system')

    system_mock.expects(:patch_if_match).with(
      {
        'Boot' => {
          'BootSourceOverrideTarget' => 'Hdd',
          'BootSourceOverrideEnabled' => 'Enabled',
        },
      }
    ).returns(true)

    @bmc.expects(:system).returns(system_mock)
    @bmc.expects(:powercycle).never

    result = @bmc.bootdevice = { :device => 'disk', :reboot => false, :persistent => true }
    refute_nil result
  end

  def test_bootdevice_with_reboot
    # Test bootdevice with reboot option
    system_mock = mock('system')

    system_mock.expects(:patch_if_match).with(
      {
        'Boot' => {
          'BootSourceOverrideTarget' => 'Pxe',
          'BootSourceOverrideEnabled' => 'Enabled',
        },
      }
    ).returns(true)

    @bmc.expects(:system).returns(system_mock)
    @bmc.expects(:powercycle).once

    result = @bmc.bootdevice = { :device => 'pxe', :reboot => true, :persistent => true }
    refute_nil result
  end

  def test_bootpxe_calls_bootdevice
    # Test that convenience method bootpxe works
    system_mock = mock('system')

    system_mock.expects(:patch_if_match).with(
      {
        'Boot' => {
          'BootSourceOverrideTarget' => 'Pxe',
          'BootSourceOverrideEnabled' => 'Once',
        },
      }
    ).returns(true)

    @bmc.expects(:system).returns(system_mock)
    @bmc.expects(:powercycle).never

    result = @bmc.bootpxe(false, false)
    refute_nil result
  end

  def test_bootdisk_calls_bootdevice
    # Test that convenience method bootdisk works
    system_mock = mock('system')

    system_mock.expects(:patch_if_match).with(
      {
        'Boot' => {
          'BootSourceOverrideTarget' => 'Hdd',
          'BootSourceOverrideEnabled' => 'Once',
        },
      }
    ).returns(true)

    @bmc.expects(:system).returns(system_mock)
    @bmc.expects(:powercycle).never

    result = @bmc.bootdisk(false, false)
    refute_nil result
  end

  def test_bootbios_calls_bootdevice
    # Test that convenience method bootbios works
    system_mock = mock('system')

    system_mock.expects(:patch_if_match).with(
      {
        'Boot' => {
          'BootSourceOverrideTarget' => 'BiosSetup',
          'BootSourceOverrideEnabled' => 'Once',
        },
      }
    ).returns(true)

    @bmc.expects(:system).returns(system_mock)
    @bmc.expects(:powercycle).never

    result = @bmc.bootbios(false, false)
    refute_nil result
  end

  def test_bootcdrom_calls_bootdevice
    # Test that convenience method bootcdrom works
    system_mock = mock('system')

    system_mock.expects(:patch_if_match).with(
      {
        'Boot' => {
          'BootSourceOverrideTarget' => 'Cd',
          'BootSourceOverrideEnabled' => 'Once',
        },
      }
    ).returns(true)

    @bmc.expects(:system).returns(system_mock)
    @bmc.expects(:powercycle).never

    result = @bmc.bootcdrom(false, false)
    refute_nil result
  end

  def test_identifystatus_uses_indicator_led_when_location_indicator_absent
    system_mock = mock('system')
    system_mock.expects(:LocationIndicatorActive).returns(nil)
    system_mock.expects(:IndicatorLED).returns('Lit')
    @bmc.expects(:system).twice.returns(system_mock)
    assert_equal 'lit', @bmc.identifystatus
  end

  def test_identifystatus_uses_location_indicator_active_true
    system_mock = mock('system')
    system_mock.expects(:LocationIndicatorActive).returns(true)
    @bmc.expects(:system).returns(system_mock)
    assert_equal 'on', @bmc.identifystatus
  end

  def test_identifystatus_uses_location_indicator_active_false
    system_mock = mock('system')
    system_mock.expects(:LocationIndicatorActive).returns(false)
    @bmc.expects(:system).returns(system_mock)
    assert_equal 'off', @bmc.identifystatus
  end

  def test_identifyon_uses_location_indicator_active_when_present
    system_mock = mock('system')
    system_mock.expects(:LocationIndicatorActive).returns(false)
    system_mock.expects(:patch_if_match).with({ 'LocationIndicatorActive' => true }).returns(true)
    @bmc.expects(:system).twice.returns(system_mock)
    @bmc.identifyon
  end

  def test_identifyon_falls_back_to_indicator_led_when_location_indicator_absent
    system_mock = mock('system')
    system_mock.expects(:LocationIndicatorActive).returns(nil)
    system_mock.expects(:patch_if_match).with({ 'IndicatorLED' => 'Lit' }).returns(true)
    @bmc.expects(:system).twice.returns(system_mock)
    @bmc.identifyon
  end

  def test_identifyoff_uses_location_indicator_active_when_present
    system_mock = mock('system')
    system_mock.expects(:LocationIndicatorActive).returns(true)
    system_mock.expects(:patch_if_match).with({ 'LocationIndicatorActive' => false }).returns(true)
    @bmc.expects(:system).twice.returns(system_mock)
    @bmc.identifyoff
  end

  def test_identifyoff_falls_back_to_indicator_led_when_location_indicator_absent
    system_mock = mock('system')
    system_mock.expects(:LocationIndicatorActive).returns(nil)
    system_mock.expects(:patch_if_match).with({ 'IndicatorLED' => 'Off' }).returns(true)
    @bmc.expects(:system).twice.returns(system_mock)
    @bmc.identifyoff
  end
end
