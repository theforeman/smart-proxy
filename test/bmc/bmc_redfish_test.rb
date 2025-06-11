require 'test_helper'
require 'bmc/bmc_plugin'
require 'bmc/redfish'
require 'test/bmc/redfish_test_helper'
require 'json'

class BmcRedfishTest < Test::Unit::TestCase
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
end
