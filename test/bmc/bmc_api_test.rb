require 'test_helper'
require 'json'
require 'bmc/bmc_plugin'
require 'bmc/bmc_api'

ENV['RACK_ENV'] = 'test'

class BmcApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::BMC::Api.new
  end

  def setup
    user     ||= ENV["ipmiuser"] || "user"
    pass     ||= ENV["ipmipass"] || "pass"
    @host    ||= ENV["ipmihost"] || "host"
    provider ||= ENV["ipmiprovider"] || "ipmitool"
    @args    = { :bmc_provider => provider }
    authorize user, pass
  end

  def test_api_throws_401_error_when_auth_is_not_provided
    Proxy::BMC::IPMI.stubs(:providers_installed).returns(['freeipmi'])
    Proxy::BMC::Plugin.settings.stubs(:bmc_default_provider).returns('freeipmi')
    auth = mock()
    auth.expects(:provided?).returns(false)
    Proxy::BMC::Api.any_instance.stubs(:auth).returns(auth)
    test_args = { :bmc_provider => 'freeipmi' }
    get "/#{host}/lan/gateway", test_args
    assert_equal 'unauthorized', last_response.body
    assert_equal 401, last_response.status
  end

  def test_api_does_not_throw_401_error_when_auth_is_provided_and_in_basic_format
    Proxy::BMC::IPMI.stubs(:providers_installed).returns(['freeipmi'])
    Proxy::BMC::Plugin.settings.stubs(:bmc_default_provider).returns('freeipmi')
    Proxy::BMC::IPMI.any_instance.stubs(:gateway).returns("192.168.1.1")
    auth = mock()
    auth.expects(:provided?).returns(true)
    auth.expects(:basic?).returns(true)
    auth.expects(:credentials).returns('username','password')
    Proxy::BMC::Api.any_instance.stubs(:auth).returns(auth)
    test_args = { :bmc_provider => 'freeipmi' }
    get "/#{host}/lan/gateway", test_args
    assert_equal 200, last_response.status
  end

  def test_api_throws_401_error_when_auth_is_not_basic
    Proxy::BMC::IPMI.stubs(:providers_installed).returns(['freeipmi'])
    Proxy::BMC::Plugin.settings.stubs(:bmc_default_provider).returns('freeipmi')
    auth = mock()
    auth.expects(:provided?).returns(true)
    auth.expects(:basic?).returns(false)
    Proxy::BMC::Api.any_instance.stubs(:auth).returns(auth)
    test_args = { :bmc_provider => 'freeipmi' }
    get "/#{host}/lan/gateway", test_args
    assert_equal 'bad_authentication_request, credentials are not in auth.basic format', last_response.body
    assert_equal 401, last_response.status
  end

  def test_api_can_put_power_action
    Proxy::BMC::IPMI.any_instance.stubs(:poweroff).returns(true)
    put "/#{host}/chassis/power/off", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_get_power_on_status
    Proxy::BMC::IPMI.any_instance.stubs(:poweron?).returns(true)
    get "/#{host}/chassis/power/on", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_get_power_off
    Proxy::BMC::IPMI.any_instance.stubs(:poweroff?).returns(true)
    get "/#{host}/chassis/power/off", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_get_ip
    Proxy::BMC::IPMI.any_instance.stubs(:ip).returns("192.168.1.1")
    get "/#{host}/lan/ip", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("192.168.1.1", data["result"].to_s)
  end

  def test_api_can_get_netmask
    Proxy::BMC::IPMI.any_instance.stubs(:netmask).returns("255.255.255.0")
    get "/#{host}/lan/netmask", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("255.255.255.0", data["result"].to_s)
  end

  def test_api_can_get_gateway
    Proxy::BMC::IPMI.any_instance.stubs(:gateway).returns("192.168.1.1")
    get "/#{host}/lan/gateway", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("192.168.1.1", data["result"].to_s)
  end

  def test_api_can_get_mac
    Proxy::BMC::IPMI.any_instance.stubs(:mac).returns("e0:f8:47:04:bc:26")
    get "/#{host}/lan/mac", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal("e0:f8:47:04:bc:26", data["result"].to_s)
  end

  def test_api_can_identify
    Proxy::BMC::IPMI.any_instance.stubs(:identifyon).returns(true)
    put "/#{host}/chassis/identify/on", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_set_pxe_boot_device
    Proxy::BMC::IPMI.any_instance.stubs(:bootpxe).returns(true)
    put "/#{host}/chassis/config/bootdevice/pxe", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_set_disk_boot_device
    Proxy::BMC::IPMI.any_instance.stubs(:bootdisk).returns(true)
    put "/#{@host}/chassis/config/bootdevice/disk", @args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_set_cdrom_boot_device
    Proxy::BMC::IPMI.any_instance.stubs(:bootcdrom).returns(true)
    put "/#{@host}/chassis/config/bootdevice/cdrom", @args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_set_bios_boot_device
    Proxy::BMC::IPMI.any_instance.stubs(:bootbios).returns(true)
    put "/#{@host}/chassis/config/bootdevice/bios", @args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_returns_actions_for_power_get
    get "/#{host}/chassis/power", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_functions_for_config_get
    get "/#{host}/chassis/config", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["functions"].length, :>, 0)
  end

  def test_api_returns_functions_for_chassis_config_get
    get "/#{host}/chassis/config/", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["functions"].length, :>, 0)
  end

  def test_api_returns_bootdevices_for_chassis_config_bootdevices_get
    get "/#{host}/chassis/config/bootdevices", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["devices"].length, :>, 0)
  end

  def test_api_returns_actions_for_power_put
    put "/#{host}/chassis/power", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_actions_for_identify_put
    put "/#{host}/chassis/identify", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_actions_for_boot_devices_put
    put "/#{host}/chassis/config/bootdevice", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_actions_for_lan
    get "/#{host}/lan", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_operator(data["actions"].length, :>, 0)
  end

  def test_api_returns_error_for_boot_devices_get
    get "/#{host}/chassis/config/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_boot_devices_put
    put "/#{host}/chassis/config/bootdevice/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_power_get
    get "/#{host}/chassis/power/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_power_put
    put "/#{host}/chassis/power/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_identify_put
    put "/#{host}/chassis/identify/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_returns_error_for_config_put
    put "/#{host}/chassis/config/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  def test_api_bmc_returns_error_correctly
    get "/#{host}/lan/bogus", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/not a valid/, data["error"])
  end

  private
  attr_reader :host, :args

end
