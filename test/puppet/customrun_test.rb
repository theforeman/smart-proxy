require 'test_helper'
require 'puppet_proxy_customrun/puppet_proxy_customrun'
require 'puppet_proxy_common/runner'
require 'puppet_proxy_customrun/customrun_main'

class CustomrunTest < Test::Unit::TestCase
  def test_arguments_can_be_array
    customrun = Proxy::PuppetCustomrun::Runner.new('/bin/false', ["-ay", "-f", "-s"])
    assert_equal ["-ay", "-f", "-s"], customrun.command_arguments
  end

  def test_arguments_string_converted_to_array
    customrun = Proxy::PuppetCustomrun::Runner.new('/bin/false', '-ay -f -s')
    assert_equal ["-ay", "-f", "-s"], customrun.command_arguments
  end

  def test_empty_arguments_string_is_converted_to_empty_array
    customrun = Proxy::PuppetCustomrun::Runner.new('/bin/false', '')
    assert customrun.command_arguments.empty?
  end

  def test_customrun
    customrun = Proxy::PuppetCustomrun::Runner.new('/bin/false', ["-ay", "-f", "-s"])
    customrun.expects(:shell_command).with(["/bin/false", "-ay", "-f", "-s", "host1", "host2"]).returns(true)
    customrun.run(["host1", "host2"])
  end

  def test_customrun_uses_shell_escaped_command
    customrun = Proxy::PuppetCustomrun::Runner.new("puppet's_run", ["-ay", "-f", "-s"])
    File.stubs(:exist?).with("puppet's_run").returns(true)
    customrun.expects(:shell_command).with(["puppet\\'s_run", "-ay", "-f", "-s", "host1", "host2"]).returns(true)
    customrun.run(["host1", "host2"])
  end
end

require 'puppet_proxy_customrun/plugin_configuration'

class CustomrunConfigurationTest < Test::Unit::TestCase
  def test_di_wiring_parameters
    container = ::Proxy::DependencyInjection::Container.new
    ::Proxy::PuppetCustomrun::PluginConfiguration.new.load_dependency_injection_wirings(container,
                                                                                        :command => "command",
                                                                                        :command_arguments => ['command', 'arguments'])

    assert_equal "command", container.get_dependency(:puppet_runner_impl).command
    assert_equal ['command', 'arguments'], container.get_dependency(:puppet_runner_impl).command_arguments
  end
end
