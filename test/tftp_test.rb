require 'test/test_helper'

class TftpTest < Test::Unit::TestCase

  def setup
    @tftp = Proxy::TFTP
  end

  def test_should_have_a_logger
    assert_respond_to @tftp, :logger
  end

  def test_should_create_tftp_link
    assert_equal @tftp.send(:path), SETTINGS.tftproot
  end

end
