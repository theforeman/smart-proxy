require 'test_helper'

class ProxyTest < Test::Unit::TestCase

  def test_should_have_a_logger
    assert_respond_to Proxy::PuppetCA, :logger
  end

  def test_which_should_return_a_binary_path
    ENV.stubs(:[]).with('PATH').returns(['/foo', '/bin', '/usr/bin'].join(File::PATH_SEPARATOR))
    { '/foo' => false, '/bin' => true, '/usr/bin' => false }.each do |p,r|
      FileTest.stubs(:file?).with("#{p}/ls").returns(r)
      FileTest.stubs(:executable?).with("#{p}/ls").returns(r)
    end
    assert_equal '/bin/ls', Proxy::PuppetCA.which('ls')
  end

  def test_should_clean_host
    #TODO
    assert_respond_to Proxy::PuppetCA, :clean
  end

  def test_should_disable_host
    #TODO
    assert_respond_to Proxy::PuppetCA, :disable
  end

  def test_should_sign_host
    #TODO
    assert_respond_to Proxy::PuppetCA, :sign
  end

end
