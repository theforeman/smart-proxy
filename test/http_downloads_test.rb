require 'test_helper'

class Proxy::HttpDownload
  def command(src, dst)
    "echo test"
  end
end

class HttpDownloadsTest < Test::Unit::TestCase
  def test_should_download_a_file
    assert Proxy::HttpDownloads.start_download 'source', 'destination'
    assert File.exist?('destination')
  ensure
    File.delete('destination')
  end

  def test_should_skip_download_if_one_is_in_progress
    locked = Proxy::FileLock.try_locking("another_destination")
    assert !(Proxy::HttpDownloads.start_download 'another_source', 'another_destination')
  ensure
    File.delete(locked.path)
  end
end
