require 'test_helper'
require 'tftp/tftp_plugin'
require "tftp/server"

class TftpTest < Test::Unit::TestCase
  def setup
    @tftp = Proxy::TFTP::Server.new
    Proxy::TFTP::Plugin.load_test_settings(:tftproot => "/some/root")
  end

  def test_should_have_a_logger
    assert_respond_to @tftp, :logger
  end

  def test_path_to_tftp_directory_without_tftproot_setting
    Proxy::TFTP::Plugin.load_test_settings({})
    assert_equal "/var/lib/tftpboot", @tftp.send(:path)
  end

  def test_path_to_tftp_directory_with_tftproot_setting
    assert_equal "/some/root", @tftp.send(:path)
  end
end
