require 'test_helper'
require 'tmpdir'

class HttpDownloadsTest < Test::Unit::TestCase
  def setup
    @timeout = Proxy::HttpDownload::DEFAULT_CONNECT_TIMEOUT
    Proxy::HttpDownload.any_instance.stubs(:which).returns('/usr/bin/curl')
  end

  def test_regular_call
    expected = [
      "/usr/bin/curl",
      "--insecure",
      "--silent", "--show-error",
      "--connect-timeout", "10",
      "--retry", "3",
      "--retry-delay", "10",
      "--max-time", "3600",
      "--remote-time",
      "--time-cond", "file", "dst",
      "--write-out", "Task done, result: %{http_code}, size downloaded: %{size_download}b, speed: %{speed_download}b/s, time: %{time_total}ms",
      "--output", "dst",
      "--location", "src"
    ]
    assert_equal expected, Proxy::HttpDownload.new('src', 'dst').command
  end

  def test_regular_call_with_ssl_verify
    expected = [
      "/usr/bin/curl",
      "--silent", "--show-error",
      "--connect-timeout", "10",
      "--retry", "3",
      "--retry-delay", "10",
      "--max-time", "3600",
      "--remote-time",
      "--time-cond", "file", "dst",
      "--write-out", "Task done, result: %{http_code}, size downloaded: %{size_download}b, speed: %{speed_download}b/s, time: %{time_total}ms",
      "--output", "dst",
      "--location", "src"
    ]
    assert_equal expected, Proxy::HttpDownload.new('src', 'dst', verify_server_cert: true).command
  end

  def test_should_skip_download_if_one_is_in_progress
    Dir.mktmpdir do |tmpdir|
      Proxy::FileLock.try_locking("#{tmpdir}/.dst.lock")
      assert_equal false, Proxy::HttpDownload.new('src', "#{tmpdir}/dst").start
    end
  end
end
