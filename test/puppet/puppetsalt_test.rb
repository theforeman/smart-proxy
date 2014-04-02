require 'test_helper'
require 'puppet/salt'

class PuppetSaltTest < Test::Unit::TestCase
  def setup
    @salt = Proxy::Puppet::Salt.new(:nodes => ['host1', 'host2'])
  end

  def test_command_line_with_default_command
    @salt.stubs(:which).with('sudo', anything).returns('/usr/bin/sudo')
    @salt.stubs(:which).with('salt', anything).returns('/usr/bin/salt')

    @salt.expects(:shell_command).with(['/usr/bin/sudo', '/usr/bin/salt', '-L', 'host1,host2', 'puppet.run']).returns(true)
    assert @salt.run
  end

  def test_missing_sudo
    @salt.stubs(:which).with('sudo', anything).returns(false)
    @salt.stubs(:which).with('salt', anything).returns('/usr/bin/salt')
    assert !@salt.run
  end

  def test_missing_salt
    @salt.stubs(:which).with('sudo', anything).returns('/usr/bin/sudo')
    @salt.stubs(:which).with('salt', anything).returns(false)
    assert !@salt.run
  end
end
