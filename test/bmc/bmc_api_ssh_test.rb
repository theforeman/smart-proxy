require 'test_helper'
require 'json'
require 'bmc/bmc_api'
require 'bmc/ssh'

ENV['RACK_ENV'] = 'test'

class BmcApiShellTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::BMC::Api.new
  end

  def setup
    @host = "somehost"
    @args = { :bmc_provider => "ssh" }
    Proxy::BMC::Plugin.load_test_settings(
      :poweron => 'echo poweron',
      :poweroff => 'echo poweroff',
      :powerstatus => 'echo powerstatus',
      :powercycle => 'echo powercycle'
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
end
