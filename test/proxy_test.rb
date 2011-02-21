require 'test_helper'

class ProxyTest < Test::Unit::TestCase
  def test_should_have_a_logger
    assert_respond_to Proxy::PuppetCA, :logger
  end

end
