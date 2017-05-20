require 'test_helper'
require 'puppet_proxy_ssh/puppet_proxy_ssh'
require 'puppet_proxy_common/runner'
require 'puppet_proxy_ssh/puppet_proxy_ssh_main'

class PuppetSshTest < Test::Unit::TestCase
  def test_command_line_with_default_command
    puppetssh = Proxy::PuppetSsh::Runner.new("puppet agent --onetime --no-usecacheonfailure", nil, nil, false, false)
    puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    command = if RUBY_VERSION <= '1.8.7'
                "puppet\\ agent\\ --onetime\\ --no-usecacheonfailure"
              else
                "puppet agent --onetime --no-usecacheonfailure"
              end

    puppetssh.
      expects(:shell_command).
      with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host1", command], false).
      returns(true)
    puppetssh.
      expects(:shell_command).
      with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host2", command], false).
      returns(true)
    assert puppetssh.run(["host1", "host2"])
  end

  def test_command_line_with_sudo
    puppetssh = Proxy::PuppetSsh::Runner.new("/bin/true", nil, nil, true, false)
    puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    puppetssh.expects(:shell_command).with(["/usr/bin/sudo", "/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host1", "/bin/true"], false).returns(true)
    puppetssh.expects(:shell_command).with(["/usr/bin/sudo", "/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host2", "/bin/true"], false).returns(true)
    assert puppetssh.run(["host1", "host2"])
  end

  def test_command_line_with_ssh_keyfile
    puppetssh = Proxy::PuppetSsh::Runner.new("/bin/true", nil, '/root/.ssh/id_rsa', false, false)
    File.stubs(:exist?).returns(true)
    puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "-i", "/root/.ssh/id_rsa", "host1", "/bin/true"], false).returns(true)
    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "-i", "/root/.ssh/id_rsa", "host2", "/bin/true"], false).returns(true)
    assert puppetssh.run(["host1", "host2"])
  end

  def test_command_line_with_ssh_keyfile_that_doesnt_exist
    puppetssh = Proxy::PuppetSsh::Runner.new("/bin/true", nil, '/root/.ssh/id_rsa', false, false)
    File.stubs(:exists?).returns(false)
    puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host1", "/bin/true"], false).returns(true)
    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host2", "/bin/true"], false).returns(true)
    assert puppetssh.run(["host1", "host2"])
  end

  def test_command_line_with_ssh_username
    puppetssh = Proxy::PuppetSsh::Runner.new("/bin/true", 'root', nil, false, false)
    puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "-l", "root", "host1", "/bin/true"], false).returns(true)
    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "-l", "root", "host2", "/bin/true"], false).returns(true)
    assert puppetssh.run(["host1", "host2"])
  end

  def test_command_line_without_sudo
    puppetssh = Proxy::PuppetSsh::Runner.new("/bin/true", nil, nil, false, false)
    puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host1", "/bin/true"], false).returns(true)
    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host2", "/bin/true"], false).returns(true)
    assert puppetssh.run(["host1", "host2"])
  end

  def test_command_line_with_puppetssh_wait
    puppetssh = Proxy::PuppetSsh::Runner.new("/bin/true", nil, nil, false, true)
    puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host1", "/bin/true"], true).returns(true)
    puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-o", "StrictHostKeyChecking=no", "host2", "/bin/true"], true).returns(true)
    assert puppetssh.run(["host1", "host2"])
  end

  def test_missing_sudo
    puppetssh = Proxy::PuppetSsh::Runner.new("/bin/true", nil, nil, true, false)
    puppetssh.stubs(:which).with("sudo", anything).returns(false)
    puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")
    puppetssh.stubs(:shell_command).returns(true)
    assert !puppetssh.run(["host1", "host2"])
  end

  def test_missing_sudo_and_not_needed
    puppetssh = Proxy::PuppetSsh::Runner.new("/bin/true", nil, nil, false, false)
    puppetssh.stubs(:which).with("sudo", anything).returns(false)
    puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")
    puppetssh.stubs(:shell_command).returns(true)
    assert puppetssh.run(["host1", "host2"])
  end

  def test_missing_ssh
    puppetssh = Proxy::PuppetSsh::Runner.new("/bin/true", nil, nil, false, false)
    puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    puppetssh.stubs(:which).with("ssh", anything).returns(false)

    assert !puppetssh.run(["host1", "host2"])
  end
end

class PuppetSshConfigurationTest < Test::Unit::TestCase
  def test_di_wiring_parameters
    container = ::Proxy::DependencyInjection::Container.new
    ::Proxy::PuppetSsh::PluginConfiguration.new.load_dependency_injection_wirings(container,
                                                                                  :command => 'a_command',
                                                                                  :use_sudo => true,
                                                                                  :wait => true,
                                                                                  :keyfile => 'a_keyfile',
                                                                                  :user => "a_user")

    assert_equal "a_command", container.get_dependency(:puppet_runner_impl).command
    assert_equal "a_user", container.get_dependency(:puppet_runner_impl).user
    assert_equal "a_keyfile", container.get_dependency(:puppet_runner_impl).keyfile_path
    assert_equal true, container.get_dependency(:puppet_runner_impl).use_sudo
    assert_equal true, container.get_dependency(:puppet_runner_impl).wait_for_command_to_finish
  end

  def test_default_settings
    Proxy::PuppetSsh::Plugin.load_test_settings({})
    assert_equal 'puppet agent --onetime --no-usecacheonfailure', Proxy::PuppetSsh::Plugin.settings.command
    assert !Proxy::PuppetSsh::Plugin.settings.use_sudo
    assert !Proxy::PuppetSsh::Plugin.settings.wait
  end
end
