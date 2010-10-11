require 'test/test_helper'

class ProxyTest < Test::Unit::TestCase

  def test_should_have_a_logger
    assert_respond_to Proxy::Puppetca, :logger
  end

  def test_which_should_return_a_binary_path
    assert Proxy::Puppetca.which("ls") == "/bin/ls"
  end

  def test_should_clean_host
    #TODO
    assert_respond_to Proxy::Puppetca, :clean
  end

  def test_should_disable_host
    #TODO
    assert_respond_to Proxy::Puppetca, :disable
  end

  def test_should_sign_host
    #TODO
    assert_respond_to Proxy::Puppetca, :sign
  end

end
