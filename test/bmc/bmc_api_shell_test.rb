require 'test_helper'
require 'json'
require 'bmc/bmc_api'
require 'bmc/shell'

ENV['RACK_ENV'] = 'test'

class BmcApiShellTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::BMC::Api.new
  end

  def setup
    @host    ||= ENV["ipmihost"] || "host"
    provider ||= ENV["ipmiprovider"] || "shell"
    @args    = { :bmc_provider => provider }
  end

  def test_api_shell_should_powercycle_with_shutdown
    Proxy::BMC::Shell.any_instance.stubs(:bmc_ssh_powercycle).returns(true)
    args = { :bmc_provider => 'shell' }
    get "/#{host}/chassis/power/cycle", args
    @args = { :username => "user", :password => "pass", :bmc_provider => "ipmitool", :host => "host" }
  end

  private
  attr_reader :host, :args

end
