require 'test_helper'
require 'puppet/puppet_plugin'
require 'puppet/puppetrun'

class PuppetRunTest < Test::Unit::TestCase
  def setup
    @puppetrun = Proxy::Puppet::PuppetRun.new(:nodes => ["host1", "host2"])
  end
  
  def test_command_line_with_puppet
    @puppetrun.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetrun.stubs(:which).with("puppet", anything).returns("/usr/sbin/puppet")
    @puppetrun.stubs(:which).with("puppetrun", anything).returns(false)
    
    @puppetrun.expects(:shell_command).with(["/usr/bin/sudo", "/usr/sbin/puppet", "kick", "--host", "host1", "--host", "host2"]).returns(true)
    assert @puppetrun.run
  end
  
  def test_command_line_with_puppet_and_puppet_user
    @puppetrun.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetrun.stubs(:which).with("puppet", anything).returns("/usr/sbin/puppet")
    @puppetrun.stubs(:which).with("puppetrun", anything).returns(false)
    Proxy::Puppet::Plugin.settings.stubs(:puppet_user).returns("example")
    
    @puppetrun.expects(:shell_command).with(["/usr/bin/sudo", "-u", "example", "/usr/sbin/puppet", "kick", "--host", "host1", "--host", "host2"]).returns(true)
    assert @puppetrun.run
  end
  
  def test_command_line_with_puppetrun
    @puppetrun.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetrun.stubs(:which).with("puppetrun", anything).returns("/usr/sbin/puppetrun")
    @puppetrun.stubs(:which).with("puppet", anything).returns(false)

    @puppetrun.expects(:shell_command).with(["/usr/bin/sudo", "/usr/sbin/puppetrun", "--host", "host1", "--host", "host2"]).returns(true)
    assert @puppetrun.run
  end

  def test_missing_sudo
    @puppetrun.stubs(:which).with("sudo", anything).returns(false)
    @puppetrun.stubs(:which).with("puppetrun", anything).returns("/usr/sbin/puppetrun")
    @puppetrun.stubs(:which).with("puppet", anything).returns(false)

    assert !@puppetrun.run
  end
  
  def test_missing_puppet
    @puppetrun.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @puppetrun.stubs(:which).with("puppetrun", anything).returns(false)
    @puppetrun.stubs(:which).with("puppet", anything).returns(false)

    assert !@puppetrun.run
  end
end
