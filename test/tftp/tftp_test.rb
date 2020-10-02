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

  def test_path_to_tftp_directory_with_relative_tftproot_setting
    Proxy::TFTP::Plugin.load_test_settings(:tftproot => "./some/root")
    assert_equal Pathname.new(__dir__).join("..", "..", "modules", "tftp", "some", "root").to_s, @tftp.send(:path)
  end

  def test_paths_inside_tftp_directory_dont_raise_errors
    ::Proxy::HttpDownload.any_instance.stubs(:start).returns(true)
    FileUtils.stubs(:mkdir_p).returns(true)

    assert Proxy::TFTP.send(:fetch_boot_file, '/some/root/boot/file', 'http://localhost/file')
  end

  def test_paths_outside_tftp_directory_raise_errors
    ::Proxy::HttpDownload.any_instance.stubs(:start).returns(true)
    FileUtils.stubs(:mkdir_p).returns(true)

    assert_raises RuntimeError do
      Proxy::TFTP.send(:fetch_boot_file, '/other/root/boot/file', 'http://localhost/file')
    end
  end

  def test_boot_filename_has_no_dash_when_prefix_ends_with_slash
    assert_equal "a/b/c/somefile", Proxy::TFTP.boot_filename('a/b/c/', '/d/somefile')
  end

  def test_boot_filename_uses_dash_when_prefix_does_not_end_with_slash
    assert_equal "a/b/c-somefile", Proxy::TFTP.boot_filename('a/b/c', '/d/somefile')
  end

  def test_choose_protocol_and_fetch_wget
    ::Proxy::HttpDownload.any_instance.expects(:start).returns(true).times(3)
    %w(http://proxy.test https://proxy.test ftp://proxy.test).each do |src|
      Proxy::TFTP.choose_protocol_and_fetch src, '/destination'
    end
  end

  def test_choose_protocol_and_fetch_wget_with_timeouts
    src = "https://proxy.test"
    dst = "/destination"
    tftp_read_timeout = "1000"
    tftp_connect_timeout = "40"
    tftp_dns_timeout = "14300"
    Proxy::TFTP::Plugin.load_test_settings(
      :tftp_read_timeout => tftp_read_timeout,
      :tftp_connect_timeout => tftp_connect_timeout,
      :tftp_dns_timeout => tftp_dns_timeout
    )

    ::Proxy::HttpDownload.expects(:new).returns(stub('tftp', :start => true)).
      with(src, dst, tftp_read_timeout, tftp_connect_timeout, tftp_dns_timeout)

    Proxy::TFTP.choose_protocol_and_fetch src, dst
  end

  def test_choose_protocol_and_fetch_wget_with_read_timeout
    src = "https://proxy.test"
    dst = "/destination"
    tftp_read_timeout = "1000"
    tftp_connect_timeout = Proxy::TFTP::Plugin.settings.tftp_connect_timeout
    tftp_dns_timeout = Proxy::TFTP::Plugin.settings.tftp_dns_timeout

    Proxy::TFTP::Plugin.load_test_settings(:tftp_read_timeout => tftp_read_timeout)

    ::Proxy::HttpDownload.expects(:new).returns(stub('tftp', :start => true)).
      with(src, dst, tftp_read_timeout, tftp_connect_timeout, tftp_dns_timeout)

    Proxy::TFTP.choose_protocol_and_fetch src, dst
  end

  def test_choose_protocol_and_fetch_nfs
    assert_nothing_raised RuntimeError do
      Proxy::TFTP.choose_protocol_and_fetch 'nfs://proxy.test', '/destination'
    end
  end

  def test_choose_protocol_and_fetch_unknown
    assert_raises RuntimeError do
      Proxy::TFTP.choose_protocol_and_fetch 'git://proxy.test', '/destination'
    end
  end
end
