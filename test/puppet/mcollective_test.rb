require 'test_helper'
require 'puppet_proxy_mcollective/puppet_proxy_mcollective'
require 'puppet_proxy_common/runner'
require 'puppet_proxy_mcollective/mcollective_main'

class MCollectiveTest < Test::Unit::TestCase
  def setup
    @mcollective = Proxy::PuppetMCollective::Runner.new(nil)
  end

  def test_run_command
    @mcollective.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @mcollective.stubs(:which).with("mco", anything).returns("/usr/bin/mco")

    @mcollective.expects(:shell_command).with(["/usr/bin/sudo", "/usr/bin/mco", "puppet", "runonce", "-I", "host1", "host2"]).returns(true)
    assert @mcollective.run(["host1", "host2"])
  end

  def test_run_command_with_mcollective_user_defined
    @mcollective = Proxy::PuppetMCollective::Runner.new("peadmin")
    @mcollective.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @mcollective.stubs(:which).with("mco", anything).returns("/usr/bin/mco")
    @mcollective.expects(:shell_command).with(["/usr/bin/sudo", "-u", "peadmin", "/usr/bin/mco", "puppet", "runonce", "-I", "host1", "host2"]).returns(true)
    assert @mcollective.run(["host1", "host2"])
  end

  def test_run_command_with_missing_sudo
    @mcollective.stubs(:which).with("sudo", anything).returns(false)
    @mcollective.stubs(:which).with("mco", anything).returns("/usr/bin/mco")

    assert !@mcollective.run(["host1", "host2"])
  end

  def test_run_command_with_missing_mco
    @mcollective.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @mcollective.stubs(:which).with("mco", anything).returns(false)

    assert !@mcollective.run(["host1", "host2"])
  end
end

class MCollectiveConfigurationTest < Test::Unit::TestCase
  def test_di_wiring_parameters
    container = ::Proxy::DependencyInjection::Container.new
    ::Proxy::PuppetMCollective::PluginConfiguration.new.load_dependency_injection_wirings(container, :user => "a_user")

    assert_equal "a_user", container.get_dependency(:puppet_runner_impl).user
  end
end
