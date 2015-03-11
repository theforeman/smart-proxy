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

  def test_api_find_ipmi_provider_logs_warning_when_specified_provider_is_not_installed
    Proxy::BMC::IPMI.stubs(:providers_installed).returns(['freeipmi'])
    Proxy::BMC::IPMI.stubs(:installed?).with('ipmitool').returns(false)
    api = Proxy::BMC::Api.new!
    api.logger.expects(:warn).with("ipmitool specified but it is not installed").at_least(1)
    api.logger.expects(:warn).with('Using freeipmi as the default BMC provider').at_least(1)
    result = api.find_ipmi_provider('ipmitool')
    assert_equal('freeipmi', result)
  end

  def test_api_find_ipmi_provider_logs_warning_when_specified_provider_is_invalid
    Proxy::BMC::IPMI.stubs(:providers_installed).returns(['freeipmi'])
    Proxy::BMC::IPMI.stubs(:installed?).with('garbage').returns(false)
    api = Proxy::BMC::Api.new!
    api.logger.expects(:warn).with('Invalid BMC type: garbage, must be one of freeipmi,ipmitool').at_least(1)
    api.logger.expects(:warn).with('Using freeipmi as the default BMC provider').at_least(1)
    result = api.find_ipmi_provider('garbage')
    assert_equal('freeipmi', result)
  end

  def test_api_find_ipmi_provider_logs_warning_when_specified_provider_is_nil
    Proxy::BMC::IPMI.stubs(:providers_installed).returns(['freeipmi'])
    Proxy::BMC::IPMI.stubs(:installed?).with(nil).returns(false)
    api = Proxy::BMC::Api.new!
    api.logger.expects(:warn).with('Invalid BMC type: , must be one of freeipmi,ipmitool').at_least(1)
    api.logger.expects(:warn).with('Using freeipmi as the default BMC provider').at_least(1)
    result = api.find_ipmi_provider(nil)
    assert_equal('freeipmi', result)
  end

  def test_api_find_ipmi_provider_halts_when_no_providers_are_installed
    Proxy::BMC::IPMI.stubs(:providers_installed).returns([])
    Proxy::BMC::IPMI.stubs(:installed?).with('freeipmi').returns(false)
    api = Proxy::BMC::Api.new!
    api.logger.expects(:warn).with("freeipmi specified but it is not installed").at_least(1)
    api.expects(:log_halt).with(400,"No BMC providers are installed, please install at least freeipmi or ipmitool").at_least(1)
    api.find_ipmi_provider('freeipmi')
  end

  def test_api_bmc_setup_returns_new_ipmi_proxy_given_ipmitool
    api = Proxy::BMC::Api.new!
    Proxy::BMC::Plugin.settings.stubs(:bmc_default_provider).returns('freeipmi')
    Proxy::BMC::Plugin.settings.stubs(:provider_log_level).returns(nil)
    auth = Object.new
    auth.stubs(:provided?).returns(true)
    auth.stubs(:basic?).returns(true)
    auth.stubs(:credentials).returns('username','password')
    api.stubs(:auth).returns(auth)
    api.stubs(:find_ipmi_provider).returns('ipmitool')
    api.stubs(:params).returns({ :bmc_provider => 'ipmitool', :host => :host })
    result = api.bmc_setup
    assert_kind_of(Proxy::BMC::IPMI,result)
  end

  def test_api_bmc_setup_returns_new_ipmi_proxy_given_freeipmi
    api = Proxy::BMC::Api.new!
    Proxy::BMC::Plugin.settings.stubs(:bmc_default_provider).returns('freeipmi')
    Proxy::BMC::Plugin.settings.stubs(:provider_log_level).returns(nil)
    auth = Object.new
    auth.stubs(:provided?).returns(true)
    auth.stubs(:basic?).returns(true)
    auth.stubs(:credentials).returns('username','password')
    api.stubs(:auth).returns(auth)
    api.stubs(:find_ipmi_provider).returns('freeipmi')
    api.stubs(:params).returns({ :bmc_provider => 'freeipmi', :host => :host })
    result = api.bmc_setup
    assert_kind_of(Proxy::BMC::IPMI,result)
  end

  def test_api_bmc_setup_returns_new_shell_proxy_given_shell
    api = Proxy::BMC::Api.new!
    Proxy::BMC::Plugin.settings.stubs(:bmc_default_provider).returns('freeipmi')
    auth = Object.new
    auth.stubs(:provided?).returns(true)
    auth.stubs(:basic?).returns(true)
    auth.stubs(:credentials).returns('username','password')
    api.stubs(:auth).returns(auth)
    api.stubs(:params).returns({ :bmc_provider => 'shell', :host => :host })
    result = api.bmc_setup
    assert_kind_of(Proxy::BMC::Shell,result)
  end

  def test_api_recovers_from_missing_provider
    Proxy::BMC::IPMI.stubs(:providers_installed).returns(['freeipmi'])
    Proxy::BMC::IPMI.stubs(:installed?).with('ipmitool').returns(false)
    test_args = { :bmc_provider => 'ipmitool' }
    Proxy::BMC::IPMI.any_instance.stubs(:test).returns(true)
    get "/#{host}/test", test_args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal true, data['result']
  end

  def test_api_recovers_from_nil_provider
    Proxy::BMC::Plugin.settings.stubs(:bmc_default_provider).returns(nil)
    Proxy::BMC::IPMI.stubs(:providers_installed).returns(['freeipmi'])
    test_args = { :bmc_provider => nil }
    Proxy::BMC::IPMI.any_instance.stubs(:test).returns(true)
    get "/#{host}/test", test_args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal true, data['result']
  end

  def test_api_returns_invalid_provider_type
    Proxy::BMC::IPMI.stubs(:providers_installed).returns([])
    test_args = { :bmc_provider => 'bogus' }
    Proxy::BMC::IPMI.any_instance.stubs(:test).returns(true)
    get "/#{host}/test", test_args
    assert_match(/No BMC providers are installed/, last_response.body)
  end

  def test_api_throws_error_when_no_providers
    Proxy::BMC::IPMI.stubs(:providers_installed).returns([])
    Proxy::BMC::IPMI.stubs(:installed?).returns(false)
    test_args = { :bmc_provider => 'freeipmi' }
    Proxy::BMC::IPMI.any_instance.stubs(:test).returns(true)
    get "/#{host}/test", test_args
    assert_match(/No BMC providers/, last_response.body)
  end

  def test_api_can_get_providers
    get "/providers", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    expected = ['freeipmi','ipmitool', 'shell']
    assert_equal(expected, data["providers"])
  end

  def test_api_can_get_installed_providers
    get "/providers/installed", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    expected = ['freeipmi','ipmitool', 'shell']
    assert_equal(expected, data["installed_providers"])
  end

  def test_api_can_get_host
    get "/host", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_equal('You need to supply the hostname or ip of the actual bmc device', data['message'].to_s)
  end

  def test_api_can_get_resources
    get "/", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    expected = ['providers', 'providers/installed', 'host']
    assert_equal(expected, data["available_resources"])
  end

  def test_api_uses_default_smart_proxy_logger
    Proxy::BMC::IPMI.logger = nil
    Proxy::BMC::Plugin.settings.stubs(:provider_log_level).returns(nil)
    Proxy::BMC::IPMI.any_instance.stubs(:poweron?).returns(true)
    get "/#{host}/chassis/power/on", args
    assert_not_equal 'Rubyipmi', Proxy::BMC::IPMI.logger.progname
    assert_equal "./logs/test.log", Proxy::BMC::IPMI.logger.instance_variable_get("@logdev").filename
  end

  def test_api_can_put_power_action
    Proxy::BMC::IPMI.any_instance.stubs(:poweroff).returns(true)
    put "/#{host}/chassis/power/off", args
    assert last_response.ok?, "Last response was not ok"
    data = JSON.parse(last_response.body)
    assert_match(/true|false/, data["result"].to_s)
  end

  def test_api_can_get_test_status
    Proxy::BMC::IPMI.any_instance.stubs(:test).returns(true)
    get "/#{host}/test", args
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
