require 'test/test_helper'

class ProxyUtilTest < Test::Unit::TestCase

  def test_util_should_support_path
    assert Proxy::Util.instance_methods.include? "which"
  end
end
