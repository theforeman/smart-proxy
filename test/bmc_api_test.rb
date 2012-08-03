require 'test_helper'
require 'helpers'
require 'bmc_api'
require 'json'

ENV['RACK_ENV'] = 'test'

class BmcApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    SmartProxy.new
  end

  def setup
    # Testing instructions
    #rake test TEST=test/bmc_api_test.rb

    user     ||= ENV["ipmiuser"] || "user"
    pass     ||= ENV["ipmipass"] || "pass"
    @host    ||= ENV["ipmihost"] || "host"
    provider ||= ENV["ipmiprovider"] || nil
    @args    = { :bmc_provider => provider }
    authorize user, pass
  end

  def test_api_can_put_power_action
    Proxy::BMC::IPMI.any_instance.stubs(:poweroff).returns(true)
    put "/bmc/#{host}/chassis/power/off", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_get_power_on_status
    Proxy::BMC::IPMI.any_instance.stubs(:poweron?).returns(true)
    get "/bmc/#{host}/chassis/power/on", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_get_power_off
    Proxy::BMC::IPMI.any_instance.stubs(:poweroff?).returns(true)
    get "/bmc/#{host}/chassis/power/off", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_get_ip
    Proxy::BMC::IPMI.any_instance.stubs(:ip).returns("192.168.1.1")
    get "/bmc/#{host}/lan/ip", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("192.168.1.1", data["result"].to_s)
  end

  def test_api_can_get_netmask
    Proxy::BMC::IPMI.any_instance.stubs(:netmask).returns("255.255.255.0")
    get "/bmc/#{host}/lan/netmask", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("255.255.255.0", data["result"].to_s)
  end

  def test_api_can_get_gateway
    Proxy::BMC::IPMI.any_instance.stubs(:gateway).returns("192.168.1.1")
    get "/bmc/#{host}/lan/gateway", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("192.168.1.1", data["result"].to_s)
  end

  def test_api_can_get_mac
    Proxy::BMC::IPMI.any_instance.stubs(:mac).returns("e0:f8:47:04:bc:26")
    get "/bmc/#{host}/lan/mac", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("e0:f8:47:04:bc:26", data["result"].to_s)
  end

  def test_api_can_identify
    Proxy::BMC::IPMI.any_instance.stubs(:identifyon).returns(true)
    put "/bmc/#{host}/chassis/identify/on", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_set_pxe_boot_device
    Proxy::BMC::IPMI.any_instance.stubs(:bootpxe).returns(true)
    put "/bmc/#{host}/chassis/config/bootdevice/pxe", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_set_disk_boot_device
    Proxy::BMC::IPMI.any_instance.stubs(:bootdisk).returns(true)
    put "/bmc/#{@host}/chassis/config/bootdevice/disk", @args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_set_cdrom_boot_device
    Proxy::BMC::IPMI.any_instance.stubs(:bootcdrom).returns(true)
    put "/bmc/#{@host}/chassis/config/bootdevice/cdrom", @args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_set_bios_boot_device
    Proxy::BMC::IPMI.any_instance.stubs(:bootbios).returns(true)
    put "/bmc/#{@host}/chassis/config/bootdevice/bios", @args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_returns_actions_for_power_get
    get "/bmc/#{host}/chassis/power", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_functions_for_config_get
    get "/bmc/#{host}/chassis/config", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["functions"].length, :>, 0)
  end

  def test_api_returns_functions_for_chassis_config_get
    get "/bmc/#{host}/chassis/config/", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["functions"].length, :>, 0)
  end

  def test_api_returns_bootdevices_for_chassis_config_bootdevices_get
    get "/bmc/#{host}/chassis/config/bootdevices", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["devices"].length, :>, 0)
  end

  def test_api_returns_actions_for_power_put
    put "/bmc/#{host}/chassis/power", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_actions_for_identify_put
    put "/bmc/#{host}/chassis/identify", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_actions_for_boot_devices_put
    put "/bmc/#{host}/chassis/config/bootdevice", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_actions_for_lan
    get "/bmc/#{host}/lan", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_error_for_boot_devices_get
    get "/bmc/#{host}/chassis/config/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_boot_devices_put
    put "/bmc/#{host}/chassis/config/bootdevice/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_power_get
    get "/bmc/#{host}/chassis/power/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_power_put
    put "/bmc/#{host}/chassis/power/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_identify_put
    put "/bmc/#{host}/chassis/identify/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_config_put
    put "/bmc/#{host}/chassis/config/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_bmc_returns_error_correctly
    get "/bmc/#{host}/lan/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  private
  attr_reader :host, :args

end
