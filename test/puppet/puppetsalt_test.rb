require 'test_helper'
require 'puppet_proxy_salt/puppet_proxy_salt'
require 'puppet_proxy_common/runner'
require 'puppet_proxy_salt/salt_main'

class PuppetSaltTest < Test::Unit::TestCase
  def setup
    @salt = Proxy::PuppetSalt::Runner.new("puppet.run")
  end

  def test_command_line_with_default_command
    @salt.stubs(:which).with('sudo', anything).returns('/usr/bin/sudo')
    @salt.stubs(:which).with('salt', anything).returns('/usr/bin/salt')

    @salt.expects(:shell_command).with(['/usr/bin/sudo', '/usr/bin/salt', '-L', 'host1,host2', 'puppet.run']).returns(true)
    assert @salt.run(['host1', 'host2'])
  end

  def test_missing_sudo
    @salt.stubs(:which).with('sudo', anything).returns(false)
    @salt.stubs(:which).with('salt', anything).returns('/usr/bin/salt')
    assert !@salt.run(['host1', 'host2'])
  end

  def test_missing_salt
    @salt.stubs(:which).with('sudo', anything).returns('/usr/bin/sudo')
    @salt.stubs(:which).with('salt', anything).returns(false)
    assert !@salt.run(['host1', 'host2'])
  end
end

class PuppetSaltConfigurationTest < Test::Unit::TestCase
  def test_di_wiring_parameters
    container = ::Proxy::DependencyInjection::Container.new
    ::Proxy::PuppetSalt::PluginConfiguration.new.load_dependency_injection_wirings(container, :command => "a_command")

    assert_equal "a_command", container.get_dependency(:puppet_runner_impl).command
  end

  def test_plugin_default_parameters
    assert_equal({:command => "puppet.run"}, ::Proxy::PuppetSalt::Plugin.default_settings)
  end
end
