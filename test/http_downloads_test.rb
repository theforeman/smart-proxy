require 'test_helper'

class Proxy::HttpDownload
  def command(src, dst)
    "echo test"
  end
end

class Proxy::HttpDownloads
  def self.downloads_in_progress
    @@downloads_in_progress
  end
end

class HttpDownloadsTest < Test::Unit::TestCase
  def test_should_download_a_file
    assert Proxy::HttpDownloads.start_download 'source', 'destination'
  end

  def test_should_skip_download_if_one_is_in_progress
    Proxy::HttpDownloads.downloads_in_progress['another_source'] = 123
    assert !(Proxy::HttpDownloads.start_download 'another_source', 'destination')
  ensure
    Proxy::HttpDownloads.downloads_in_progress.delete('another_source')
  end
end
