require 'test_helper'
require 'puppet_proxy_common/runner'

class RunnerTest < Test::Unit::TestCase
  def setup
    @runner = Proxy::Puppet::Runner.new
  end

  def test_shell_escaped_nodes
    assert_equal ['foo', 'bar', 'foo\ bar'], @runner.shell_escaped_nodes(['foo', 'bar', 'foo bar'])
  end

  def test_shell_command_true
    assert @runner.shell_command(['true'])
  end

  def test_shell_command_false
    assert !@runner.shell_command(['false'])
  end
end
