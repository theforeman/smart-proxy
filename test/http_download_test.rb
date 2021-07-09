require 'test_helper'
require 'tmpdir'

class HttpDownloadsTest < Test::Unit::TestCase
  def tmp(name)
    File.join(Dir.tmpdir(), "http-download-#{name}.tmp")
  end

  def test_should_construct_escaped_wget_command
    default_read = Proxy::HttpDownload::DEFAULT_READ_TIMEOUT
    default_connect = Proxy::HttpDownload::DEFAULT_CONNECT_TIMEOUT
    default_dns = Proxy::HttpDownload::DEFAULT_DNS_TIMEOUT

    expected = ["/wget",
                "--connect-timeout=#{default_connect}",
                "--dns-timeout=#{default_dns}",
                "--read-timeout=#{default_read}",
                "--tries=3", "--no-check-certificate", "--timestamping", "--no-if-modified-since", "-nv", "src", "-O", "dst"]
    Proxy::HttpDownload.any_instance.stubs(:which).returns('/wget')
    assert_equal expected, Proxy::HttpDownload.new('src', 'dst').command
  end

  def test_should_construct_escaped_wget_command_only_read
    default_connect = Proxy::HttpDownload::DEFAULT_CONNECT_TIMEOUT
    default_dns = Proxy::HttpDownload::DEFAULT_DNS_TIMEOUT

    read_timeout = 1000
    expected = ["/wget",
                "--connect-timeout=#{default_connect}",
                "--dns-timeout=#{default_dns}",
                "--read-timeout=#{read_timeout}",
                "--tries=3", "--no-check-certificate", "--timestamping", "--no-if-modified-since", "-nv", "src", "-O", "dst"]
    Proxy::HttpDownload.any_instance.stubs(:which).returns('/wget')
    assert_equal expected, Proxy::HttpDownload.new('src', 'dst', read_timeout, nil, nil).command
  end

  def test_should_construct_escaped_wget_command_all_timeout_options
    read_timeout = 1000
    connect_timeout = 99
    dns_timeout = 27
    expected = ["/wget",
                "--connect-timeout=#{connect_timeout}",
                "--dns-timeout=#{dns_timeout}",
                "--read-timeout=#{read_timeout}",
                "--tries=3", "--no-check-certificate", "--timestamping", "--no-if-modified-since", "-nv", "src", "-O", "dst"]
    Proxy::HttpDownload.any_instance.stubs(:which).returns('/wget')
    assert_equal expected, Proxy::HttpDownload.new('src', 'dst', read_timeout, connect_timeout, dns_timeout).command
  end

  def test_should_skip_download_if_one_is_in_progress
    locked = Proxy::FileLock.try_locking(tmp('other'))
    assert_equal false, Proxy::HttpDownload.new('src', locked.path).start
  ensure
    File.delete(locked.path)
  end
end
