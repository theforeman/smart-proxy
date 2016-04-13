require 'test_helper'
require 'puppet_proxy_common/runner'
require 'puppet_proxy_puppetrun/puppet_proxy_puppetrun'
require 'puppet_proxy_puppetrun/puppetrun_main'

class PuppetRunTest < Test::Unit::TestCase
  def setup
    @puppetrun = Proxy::PuppetRun::Runner.new(nil)
  end

  def test_command_line_with_puppet
    @puppetrun.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetrun.stubs(:which).with("puppet", anything).returns("/usr/sbin/puppet")
    @puppetrun.stubs(:which).with("puppetrun", anything).returns(false)

    @puppetrun.expects(:shell_command).with(["/usr/bin/sudo", "/usr/sbin/puppet", "kick", "--host", "host1", "--host", "host2"]).returns(true)
    assert @puppetrun.run(["host1", "host2"])
  end

  def test_command_line_with_puppet_and_puppet_user
    @puppetrun = Proxy::PuppetRun::Runner.new("example")
    @puppetrun.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetrun.stubs(:which).with("puppet", anything).returns("/usr/sbin/puppet")
    @puppetrun.stubs(:which).with("puppetrun", anything).returns(false)

    @puppetrun.expects(:shell_command).with(["/usr/bin/sudo", "-u", "example", "/usr/sbin/puppet", "kick", "--host", "host1", "--host", "host2"]).returns(true)
    assert @puppetrun.run(["host1", "host2"])
  end

  def test_command_line_with_puppetrun
    @puppetrun.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetrun.stubs(:which).with("puppetrun", anything).returns("/usr/sbin/puppetrun")
    @puppetrun.stubs(:which).with("puppet", anything).returns(false)

    @puppetrun.expects(:shell_command).with(["/usr/bin/sudo", "/usr/sbin/puppetrun", "--host", "host1", "--host", "host2"]).returns(true)
    assert @puppetrun.run(["host1", "host2"])
  end

  def test_missing_sudo
    @puppetrun.stubs(:which).with("sudo", anything).returns(false)
    @puppetrun.stubs(:which).with("puppetrun", anything).returns("/usr/sbin/puppetrun")
    @puppetrun.stubs(:which).with("puppet", anything).returns(false)

    assert !@puppetrun.run(["host1", "host2"])
  end

  def test_missing_puppet
    @puppetrun.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetrun.stubs(:which).with("puppetrun", anything).returns(false)
    @puppetrun.stubs(:which).with("puppet", anything).returns(false)

    assert !@puppetrun.run(["host1", "host2"])
  end
end

class PuppetRunConfigurationTest < Test::Unit::TestCase
  def test_di_wiring_parameters
    container = ::Proxy::DependencyInjection::Container.new
    ::Proxy::PuppetRun::PluginConfiguration.new.load_dependency_injection_wirings(container, :user => "a_user")

    assert_equal "a_user", container.get_dependency(:puppet_runner_impl).user
  end
end
