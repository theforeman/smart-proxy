require 'test_helper'
require 'json'
require 'bmc/bmc_api'
require 'bmc/ssh'
require 'bmc/bmc_plugin'

ENV['RACK_ENV'] = 'test'

class BmcApiShellTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Proxy::BMC::Api.new
  end

  def setup
    @host = "somehost"
    @args = { :bmc_provider => "ssh" }
    Proxy::BMC::Plugin.load_test_settings(
      :bmc_ssh_poweron => 'echo poweron',
      :bmc_ssh_poweroff => 'echo poweroff',
      :bmc_ssh_powerstatus => 'echo powerstatus',
      :bmc_ssh_powercycle => 'echo powercycle'
    )
  end

  def test_powerstatus
    Proxy::BMC::SSH.any_instance.expects(:ssh).with("echo powerstatus").returns(true)
    get "/#{@host}/chassis/power/status", @args
    assert_equal 200, last_response.status
  end

  def test_poweroff
    Proxy::BMC::SSH.any_instance.expects(:ssh).with("echo poweroff").returns(true)
    put "/#{@host}/chassis/power/off", @args
    assert_equal 200, last_response.status
  end

  def test_poweron
    Proxy::BMC::SSH.any_instance.expects(:ssh).with("echo poweron").returns(true)
    put "/#{@host}/chassis/power/on", @args
    assert_equal 200, last_response.status
  end

  def test_powercycle
    Proxy::BMC::SSH.any_instance.expects(:ssh).with("echo powercycle").returns(true)
    put "/#{@host}/chassis/power/cycle", @args
    assert_equal 200, last_response.status
  end

  def test_lan_ip_when_host_is_ip
    host = "192.168.1.1"
    get "/#{host}/lan/ip", @args
    assert_equal 200, last_response.status
    assert_equal host, JSON.parse(last_response.body)["result"]
  end

  def test_lan_ip_when_host_is_ipv6
    host = '2001:db8::1'
    get "/#{host}/lan/ip", @args
    assert_equal 200, last_response.status
    assert_equal host, JSON.parse(last_response.body)['result']
  end

  def test_lan_ip_when_host_is_resolvable_fqdn
    host = "resolvable.example.com"
    resolved_ip = "192.168.1.2"
    Resolv.expects(:getaddress).with(host).returns(resolved_ip)
    get "/#{host}/lan/ip", @args
    assert_equal 200, last_response.status
    assert_equal resolved_ip, JSON.parse(last_response.body)["result"]
  end

  def test_lan_ip_when_host_is_unresolvable_fqdn
    host = "unresolvable.example.com"
    Resolv.expects(:getaddress).with(host).raises(Resolv::ResolvError.new("no address for #{host}"))
    get "/#{host}/lan/ip", @args
    assert_equal 200, last_response.status
    assert_equal "", JSON.parse(last_response.body)["result"]
  end

  def test_lan_mac
    Proxy::BMC::SSH.any_instance.expects(:mac).returns('')
    get "/#{@host}/lan/mac", @args
    assert_equal 200, last_response.status
  end

  def test_lan_gateway
    Proxy::BMC::SSH.any_instance.expects(:gateway).returns('')
    get "/#{@host}/lan/gateway", @args
    assert_equal 200, last_response.status
  end

  def test_lan_netmask
    Proxy::BMC::SSH.any_instance.expects(:netmask).returns('')
    get "/#{@host}/lan/netmask", @args
    assert_equal 200, last_response.status
  end

  def test_chassis_config_bootdevice_pxe
    Proxy::BMC::SSH.any_instance.expects(:bootpxe).returns('')
    put "/#{@host}/chassis/config/bootdevice/pxe", @args
    assert_equal 200, last_response.status
  end

  def test_chassis_config_bootdevice_disk
    Proxy::BMC::SSH.any_instance.expects(:bootdisk).returns('')
    put "/#{@host}/chassis/config/bootdevice/disk", @args
    assert_equal 200, last_response.status
  end

  def test_chassis_config_bootdevice_bios
    Proxy::BMC::SSH.any_instance.expects(:bootbios).returns('')
    put "/#{@host}/chassis/config/bootdevice/bios", @args
    assert_equal 200, last_response.status
  end

  def test_chassis_config_bootdevice_cdrom
    Proxy::BMC::SSH.any_instance.expects(:bootcdrom).returns('')
    put "/#{@host}/chassis/config/bootdevice/cdrom", @args
    assert_equal 200, last_response.status
  end
end
