require 'test_helper'

class ProxyUtilTest < Test::Unit::TestCase

  def test_util_should_support_path
    assert Proxy::Util.instance_methods.include? "which"
  end

  def test_commandtask_with_echo_exec
    t = Proxy::Util::CommandTask.new('echo test')
    assert_equal t.join, 0
  end

  def test_commandtask_with_wget_invalidport_exec
    t = Proxy::Util::CommandTask.new("wget --no-check-certificate -c http://127.0.0.2 -O /dev/null")

    # return code is not correct in Ruby<1.9 for open3 (http://redmine.ruby-lang.org/issues/show/1287)
    if RUBY_VERSION =~ /1\.8\.\d+/
      assert_equal t.join, 0
    else
      assert_equal t.join, 4
    end
  end
end
