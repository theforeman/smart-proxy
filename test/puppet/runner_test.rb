require 'test_helper'
require 'puppet_proxy/runner'

class RunnerTest < Test::Unit::TestCase
  def setup
    @runner = Proxy::Puppet::Runner.new(:nodes => ['foo', 'bar', 'foo bar'])
  end

  def test_shell_escaped_nodes
    assert_equal ['foo', 'bar', 'foo\ bar'], @runner.send(:shell_escaped_nodes)
  end

  def test_shell_command_true
    success = @runner.send(:shell_command, ['true'])
    assert_equal true, success
  end

  def test_shell_command_false
    success = @runner.send(:shell_command, ['false'])
    assert_equal false, success
  end
end
