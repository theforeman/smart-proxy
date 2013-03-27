require 'test_helper'
require 'helpers'
require 'bmc_api'
require 'json'

ENV['RACK_ENV'] = 'test'

class BmcApiShellTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    SmartProxy.new
  end

  def setup
    # Testing instructions
    #rake test TEST=test/bmc_api_test.rb

    @host    ||= ENV["ipmihost"] || "host"
    provider ||= ENV["ipmiprovider"] || "shell"
    @args    = { :bmc_provider => provider }
    require 'proxy/bmc/shell'
  end

  def test_api_shell_should_powercycle_with_shutdown
    Proxy::BMC::Shell.any_instance.stubs(:powercycle).returns(true)
    args = { :bmc_provider => 'shell' }
    get "/bmc/#{host}/chassis/power/cycle", args
    @args = { :username => "user", :password => "pass", :bmc_provider => "ipmitool", :host => "host" }
  end

  private
  attr_reader :host, :args

end
