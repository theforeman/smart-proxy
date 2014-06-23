require 'test_helper'
require 'puppet_proxy/runner'

class RunnerTest < Test::Unit::TestCase
  def setup
    @runner = Proxy::Puppet::Runner.new({})
  end

  def test_popen
    @runner.send(:popen, ["echo", "blah"])
    assert_equal 0, $?.exitstatus
  end
end
