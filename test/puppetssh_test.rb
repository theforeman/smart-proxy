require 'test_helper'
require 'proxy/puppet/puppet_ssh'

class PuppetSshTest < Test::Unit::TestCase
  def setup
    @puppetssh = Proxy::Puppet::PuppetSSH.new(:nodes => ["host1", "host2"])
  end

  def test_command_line_with_default_command
    @puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "host1", "puppet\\ agent\\ --onetime\\ --no-usecacheonfailure"], false).returns(true)
    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "host2", "puppet\\ agent\\ --onetime\\ --no-usecacheonfailure"], false).returns(true)
    assert @puppetssh.run
  end

  def test_command_line_with_sudo
    SETTINGS.stubs(:puppetssh_sudo).returns(true)
    SETTINGS.stubs(:puppetssh_command).returns('/bin/true')
    @puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    @puppetssh.expects(:shell_command).with(["/usr/bin/sudo", "/usr/bin/ssh", "host1", "/bin/true"], false).returns(true)
    @puppetssh.expects(:shell_command).with(["/usr/bin/sudo", "/usr/bin/ssh", "host2", "/bin/true"], false).returns(true)
    assert @puppetssh.run
  end

  def test_command_line_with_ssh_keyfile
    SETTINGS.stubs(:puppetssh_keyfile).returns('/root/.ssh/id_rsa')
    SETTINGS.stubs(:puppetssh_command).returns('/bin/true')
    File.stubs(:exists?).returns(true)
    @puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-i", "/root/.ssh/id_rsa", "host1", "/bin/true"], false).returns(true)
    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-i", "/root/.ssh/id_rsa", "host2", "/bin/true"], false).returns(true)
    assert @puppetssh.run
  end

  def test_command_line_with_ssh_keyfile_that_doesnt_exists
    SETTINGS.stubs(:puppetssh_keyfile).returns('/root/.ssh/id_rsa')
    SETTINGS.stubs(:puppetssh_command).returns('/bin/true')
    File.stubs(:exists?).returns(false)
    @puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "host1", "/bin/true"], false).returns(true)
    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "host2", "/bin/true"], false).returns(true)
    assert @puppetssh.run
  end

  def test_command_line_with_ssh_username
    SETTINGS.stubs(:puppetssh_user).returns('root')
    SETTINGS.stubs(:puppetssh_command).returns('/bin/true')
    @puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-l", "root", "host1", "/bin/true"], false).returns(true)
    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "-l", "root", "host2", "/bin/true"], false).returns(true)
    assert @puppetssh.run
  end

  def test_command_line_without_sudo
    SETTINGS.stubs(:puppetssh_command).returns('/bin/true')
    @puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")

    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "host1", "/bin/true"], false).returns(true)
    @puppetssh.expects(:shell_command).with(["/usr/bin/ssh", "host2", "/bin/true"], false).returns(true)
    assert @puppetssh.run
  end

  def test_missing_sudo
    SETTINGS.stubs(:puppetssh_sudo).returns(true)
    @puppetssh.stubs(:which).with("sudo", anything).returns(false)
    @puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")
    @puppetssh.stubs(:shell_command).returns(true)
    assert !@puppetssh.run
  end

  def test_missing_sudo_and_not_needed
    SETTINGS.stubs(:puppetssh_sudo).returns(false)
    @puppetssh.stubs(:which).with("sudo", anything).returns(false)
    @puppetssh.stubs(:which).with("ssh", anything).returns("/usr/bin/ssh")
    @puppetssh.stubs(:shell_command).returns(true)
    assert @puppetssh.run
  end

  def test_missing_ssh
    @puppetssh.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetssh.stubs(:which).with("ssh", anything).returns(false)

    assert !@puppetssh.run
  end
end
