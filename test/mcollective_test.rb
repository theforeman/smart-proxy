require 'test_helper'
require 'proxy/puppet/mcollective'

class MCollectiveTest < Test::Unit::TestCase
  def setup
    @mcollective = Proxy::Puppet::MCollective.new(:nodes => ["host1", "host2"])
  end
  
  def test_run_command
    @mcollective.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @mcollective.stubs(:which).with("mco", anything).returns("/usr/bin/mco")

    @mcollective.expects(:shell_command).with(["/usr/bin/sudo", "/usr/bin/mco", "puppet", "runonce", "-I", "host1", "host2"]).returns(true)
    assert @mcollective.run
  end

  def test_run_command_with_missing_sudo
    @mcollective.stubs(:which).with("sudo", anything).returns(false)
    @mcollective.stubs(:which).with("mco", anything).returns("/usr/bin/mco")

    assert !@mcollective.run
  end

  def test_run_command_with_missing_mco
    @mcollective.stubs(:which).with("sudo", anything).returns("/usr/bin/sudo")
    @mcollective.stubs(:which).with("mco", anything).returns(false)

    assert !@mcollective.run
  end
end