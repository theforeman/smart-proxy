require 'test_helper'

class TftpTest < Test::Unit::TestCase
  def setup
    @tftp = Proxy::TFTP::Tftp.new
  end

  def test_should_have_a_logger
    assert_respond_to @tftp, :logger
  end

  def test_path_to_tftp_directory_without_tftproot_setting
    assert_equal Pathname.new(__FILE__).join("..", "..", "lib","proxy","tftpboot").to_s, @tftp.send(:path)
  end

  def test_path_to_tftp_directory_with_tftproot_setting
    SETTINGS.stubs(:tftproot).returns("/some/tftp/root")
    assert_equal SETTINGS.tftproot, @tftp.send(:path)
  end

  def test_path_to_tftp_directory_with_relative_tftproot_setting
    SETTINGS.stubs(:tftproot).returns("./some/root")
    assert_equal Pathname.new(__FILE__).join("..", "..", "lib","proxy","some","root").to_s, @tftp.send(:path)
  end

  def test_paths_inside_tftp_directory_dont_raise_errors
    SETTINGS.stubs(:tftproot).returns("/some/root")
    Proxy::Util::CommandTask.stubs(:new).returns(true)
    FileUtils.stubs(:mkdir_p).returns(true)
    assert Proxy::TFTP.send(:fetch_boot_file,'/some/root/boot/file','http://localhost/file')
  end

  def test_paths_outside_tftp_directory_raise_errors
    SETTINGS.stubs(:tftproot).returns("/some/root")
    Proxy::Util::CommandTask.stubs(:new).returns(true)
    FileUtils.stubs(:mkdir_p).returns(true)
    assert_raises RuntimeError do
      Proxy::TFTP.send(:fetch_boot_file,'/other/root/boot/file','http://localhost/file')
    end
  end

end
