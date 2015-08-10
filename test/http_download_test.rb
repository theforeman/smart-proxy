require 'test_helper'
require 'tmpdir'

class HttpDownloadsTest < Test::Unit::TestCase
  def tmp(name)
    File.join(Dir.tmpdir(), "http-download-#{name}.tmp")
  end

  def test_should_construct_escaped_wget_command
    expected = "/wget --timeout=10 --tries=3 --no-check-certificate -nv -c \"src\" -O \"dst\""
    Proxy::HttpDownload.any_instance.stubs(:which).returns('/wget')
    assert_equal expected, Proxy::HttpDownload.new('src', 'dst').command
  end

  def test_should_skip_download_if_one_is_in_progress
    locked = Proxy::FileLock.try_locking(tmp('other'))
    assert_equal false, Proxy::HttpDownload.new('src', locked.path).start
  ensure
   File.delete(locked.path)
  end
end
