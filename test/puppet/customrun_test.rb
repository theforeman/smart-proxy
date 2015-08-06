require 'test_helper'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/customrun'

class CustomRunTest < Test::Unit::TestCase
  def setup
    @customrun = Proxy::Puppet::CustomRun.new(:nodes => ["host1", "host2"])
  end

  def test_customrun
    ::Proxy::Puppet::Plugin.load_test_settings(:customrun_cmd => "/bin/false", :customrun_args => "-ay -f -s")
    @customrun.expects(:shell_command).with(["/bin/false", "-ay", "-f", "-s", "host1", "host2"]).returns(true)
    @customrun.run
  end

  def test_customrun_with_array_command_args
    ::Proxy::Puppet::Plugin.load_test_settings(:customrun_cmd => "/bin/false", :customrun_args => ["-ay", "-f", "-s"])
    @customrun.expects(:shell_command).with(["/bin/false", "-ay", "-f", "-s", "host1", "host2"]).returns(true)
    @customrun.run
  end

  def test_customrun_uses_shell_escaped_command
    ::Proxy::Puppet::Plugin.load_test_settings(:customrun_cmd => "puppet's_run", :customrun_args => "-ay -f -s")
    File.stubs(:exist?).with("puppet's_run").returns(true)

    @customrun.expects(:shell_command).with(["puppet\\'s_run", "-ay", "-f", "-s", "host1", "host2"]).returns(true)
    @customrun.run
  end
end