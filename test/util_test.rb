require 'test_helper'

class ProxyUtilTest < Test::Unit::TestCase

  def test_util_should_support_path
    assert Proxy::Util.instance_methods.include? RUBY_VERSION >= '1.9.3' ? :which : "which"
  end

  def test_commandtask_with_echo_exec
    t = Proxy::Util::CommandTask.new('echo test')
    # ruby 1.9 seems to return nil for $? in open3
    assert_equal t.join, RUBY_VERSION =~ /1\.8\.\d+/  ? 0 : nil
  end

  def test_commandtask_with_wget_invalidport_exec
    t = Proxy::Util::CommandTask.new("wget --no-check-certificate -c http://127.0.0.2 -O /dev/null")

    # return code is not correct in Ruby<1.9 for open3 (http://redmine.ruby-lang.org/issues/show/1287)
    # ruby 1.9 seems to return nil for $? in open3
    assert_equal t.join, RUBY_VERSION =~ /1\.8\.\d+/  ? 0 : nil
  end
end
