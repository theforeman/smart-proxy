require 'test_helper'
require 'tftp/http_downloads'
require 'json'
require 'fileutils'

class HttpDownloadsTest < Test::Unit::TestCase
  def setup
    @dir = Dir.mktmpdir
    @downloads = ::Proxy::TFTP::HttpDownloads.new(@dir, SuccessfulDownload)
  end

  def teardown
    FileUtils.remove_entry_secure(@dir) unless @dir.nil?
  end

  def test_download_creates_metadata
    @downloads.stubs(:start_or_restart_download)
    @downloads.do_download(tmp_path('test'), tmp_path('test_tmp'), metadata_path = tmp_path('test_metadata'), url = 'http://localhost')

    assert File.exist?(metadata_path)
    assert_equal url, JSON.parse(IO.read(metadata_path))['url']
  end

  def test_download_raises_error_if_file_is_being_saved_outside_of_downloads_directory
    assert_raises(RuntimeError) { @downloads.download(File.expand_path('../../../', @dst), 'http://localhost') }
  end

  def test_download_creates_subdirectories
    @downloads.stubs(:start_or_restart_download)
    @downloads.do_download(tmp_path('a/b/c/test'), tmp_path('a/b/c/test_tmp'), tmp_path('a/b/c/test_metadata'), 'http://localhost')
    assert File.exist?(tmp_path('a/b/c'))
  end

  def test_download_checks_local_copy
    url = 'http://localhost'
    SuccessfulDownload.any_instance.expects(:is_local_copy_stale?).with(@downloads.filepath('', url)).returns(false)
    @downloads.expects(:do_download).never
    @downloads.download('', url)
  end

  def test_download_proceeds_if_local_copy_is_stale
    url = 'http://localhost'
    SuccessfulDownload.any_instance.expects(:is_local_copy_stale?).with(@downloads.filepath('', url)).returns(true)
    @downloads.expects(:do_download)
    @downloads.download('', url)
  end

  def test_cleanup_after_successful_download
    @downloads.do_download(path = tmp_path('test'), tmp_path = tmp_path('test_tmp'), metadata_path = tmp_path('test_metadata'), 'http://localhost')
    @downloads.download_in_progress.wait(5)

    assert @downloads.download_in_progress.complete?
    assert File.exist?(path)
    assert_false File.exist?(tmp_path)
    assert_false File.exist?(metadata_path)
  end

  def test_cleanup_is_skipped_when_download_is_stopped
    downloads = ::Proxy::TFTP::HttpDownloads.new(@dir, StoppedDownload)
    downloads.do_download(path = tmp_path('test'), tmp_path = tmp_path('test_tmp'), metadata_path = tmp_path('test_metadata'), 'http://localhost')
    downloads.download_in_progress.wait(5)

    assert downloads.download_in_progress.complete?
    assert_false File.exist?(path)
    assert File.exist?(tmp_path)
    assert File.exist?(metadata_path)
  end

  def test_cleanup_after_failed_download
    downloads = ::Proxy::TFTP::HttpDownloads.new(@dir, FailedDownload)
    downloads.do_download(path = tmp_path('test'), tmp_path = tmp_path('test_tmp'), metadata_path = tmp_path('test_metadata'), 'http://localhost')
    downloads.download_in_progress.wait(5)

    assert downloads.download_in_progress.complete?
    assert_false File.exist?(path)
    assert_false File.exist?(tmp_path)
    assert_false File.exist?(metadata_path)
  end

  def test_cleanup_after_failing_to_start_download
    @downloads.expects(:create_metadata).raises("Error")
    @downloads.do_download(path = tmp_path('test'), tmp_path = tmp_path('test_tmp'), metadata_path = tmp_path('test_metadata'), 'http://localhost') rescue nil

    assert_false File.exist?(path)
    assert_false File.exist?(tmp_path)
    assert_false File.exist?(metadata_path)
  end

  def test_url_to_download_mapping_cleanup
    @downloads.do_download(tmp_path('test'), tmp_path('test_tmp'), tmp_path('test_metadata'), url = 'http://localhost')
    @downloads.download_in_progress.wait(5)

    assert @downloads.download_in_progress.complete?
    assert_false @downloads.url_to_download.key?(url)
  end

  def test_url_to_download_mapping_cleanup_on_error
    downloads = ::Proxy::TFTP::HttpDownloads.new(@dir, FailedDownload)
    downloads.do_download(tmp_path('test'), tmp_path('test_tmp'), tmp_path('test_metadata'), url = 'http://localhost')
    downloads.download_in_progress.wait(5)

    assert downloads.download_in_progress.complete?
    assert_false downloads.url_to_download.key?(url)
  end

  def test_should_reuse_downloads
    @downloads.url_to_download['http://localhost/1'] = '123456'
    assert_equal '123456', @downloads.do_download('tmp', 'tmp.tmp', 'tmp.metadata', 'http://localhost/1')
  end

  def test_restart_downloads
    @downloads.create_metadata(tmp_path('first.1.metadata'), 'http://localhost/1', '123456')
    @downloads.create_metadata(tmp_path('second.2.metadata'), 'http://localhost/2', '789012')

    @downloads.expects(:do_download).with(tmp_path('first'), tmp_path('first.1.tmp'), tmp_path('first.1.metadata'), 'http://localhost/1', '123456', true)
    @downloads.expects(:do_download).with(tmp_path('second'), tmp_path('second.2.tmp'), tmp_path('second.2.metadata'), 'http://localhost/2', '789012', true)

    @downloads.restart_downloads
  end

  def test_boot_filename_has_no_dash_when_prefix_ends_with_slash
    assert_equal "a/b/c/somefile", @downloads.boot_filename('a/b/c/', '/d/somefile')
  end

  def test_boot_filename_uses_dash_when_prefix_does_not_end_with_slash
    assert_equal "a/b/c-somefile", @downloads.boot_filename('a/b/c', '/d/somefile')
  end

  def tmp_path(filename)
    File.join(@dir, filename)
  end

  class SuccessfulDownload < ::Proxy::TFTP::HttpDownload
    def download; Concurrent::Promise.new { FileUtils.touch(@dst) }; end
  end

  class FailedDownload < ::Proxy::TFTP::HttpDownload
    def download; Concurrent::Promise.new { raise ::Proxy::TFTP::HttpError.new('500', 'Error') }; end
  end

  class StoppedDownload < ::Proxy::TFTP::HttpDownload
    def download; Concurrent::Promise.new { @status.stopped = true; FileUtils.touch(@dst) }; end
  end
end

require 'tempfile'

class HttpDownloadTest < Test::Unit::TestCase
  def setup
    @dst = (@tmp_file = Tempfile.new('http_download_test')).path
    @url = 'http://localhost/first'
    @http_download = Proxy::TFTP::HttpDownload.new(@dst, @url)
  ensure
    @tmp_file.close
  end

  def teardown
    @tmp_file.unlink
  end

  def test_is_local_copy_stale_if_file_is_missing
    assert @http_download.is_local_copy_stale?('/non/existent/path')
  end

  # remote size will be zero if content-length header is corrupted
  def test_is_local_copy_stale_if_remote_size_is_zero
    Proxy::TFTP::HttpDownload::Downloader.any_instance.expects(:size).returns(0)
    assert @http_download.is_local_copy_stale?(@dst)
  end

  def test_is_local_copy_stale_if_remote_returns_error
    Proxy::TFTP::HttpDownload::Downloader.any_instance.expects(:size).raises(::Proxy::TFTP::HttpError.new(500, "error"))
    assert @http_download.is_local_copy_stale?(@dst)
  end

  def test_is_local_copy_stale_if_remote_size_is_different
    Proxy::TFTP::HttpDownload::Downloader.any_instance.expects(:size).returns(File.size(@dst) + 1)
    assert @http_download.is_local_copy_stale?(@dst)
  end

  def test_is_local_copy_stale_if_remote_size_is_same
    Proxy::TFTP::HttpDownload::Downloader.any_instance.expects(:size).returns(File.size(@dst))
    assert @http_download.is_local_copy_stale?(@dst)
  end
end

require 'webmock/test_unit'

class DownloaderTest < Test::Unit::TestCase
  def setup
    @dst = (@tmp_file = Tempfile.new('http_download_test')).path
    @url = 'http://localhost/first'
    @body = "bunch of stuff"
    @status = Proxy::TFTP::HttpDownload::Status.new
    @downloader = Proxy::TFTP::HttpDownload::Downloader.new(URI.parse(@url), @dst, @status)
  ensure
    @tmp_file.close
  end

  def teardown
    WebMock::StubRegistry.instance.reset!
    @tmp_file.unlink
  end

  def test_download
    stub_request(:get, @url).to_return(:status => [200, 'OK'], :body => @body)
    @downloader.start
    assert_equal @body, IO.read(@dst)
  end

  def test_should_update_downloaded_counter
    stub_request(:get, @url).to_return(:status => [200, 'OK'], :body => @body)
    @downloader.start
    assert_equal @body.size, @status.downloaded
  end

  def test_should_set_file_length_to_zero_if_content_length_header_is_absent
    stub_request(:get, @url).to_return(:status => [200, 'OK'], :body => @body)
    @downloader.start
    assert_equal 0, @status.file_length
  end

  def test_should_set_file_length_to_content_length_header_value
    stub_request(:get, @url).to_return(:status => [200, 'OK'], :headers => { 'Content-Length' => 42 }, :body => @body)
    @downloader.start
    assert_equal 42, @status.file_length
  end

  def test_should_use_range_header_on_restart
    stub_request(:get, @url).with(:headers => {'Range' => 'bytes=100-'}).to_return(:status => [200, 'OK'], :body => @body)
    @downloader.start(100)
  end

  def test_should_update_downloaded_counter_on_restart_if_server_supports_partial_responses
    stub_request(:get, @url).to_return(:status => [206, 'OK'], :body => '')
    @downloader.start(42)
    assert_equal 42, @status.downloaded
  end

  def test_should_append_to_existing_file_on_partial_response
    to_append = 'more_stuff'
    IO.write(@dst, @body)
    stub_request(:get, @url).to_return(:status => [206, 'OK'], :body => to_append)

    @downloader.start(@body.size)
    assert_equal @body+to_append, IO.read(@dst)
  end

  def should_stop_download_on_stop
    stub_request(:get, @url).to_return(:status => [200, 'OK'], :body => @body)
    @downloader.stop
    @downloader.start

    assert @status.stopped?
    assert_equal 0, @status.downloaded
  end

  def test_should_raise_exception_if_response_was_not_ok
    stub_request(:get, @url).to_return(:status => [404, 'not found'])
    assert_raises(::Proxy::TFTP::HttpError) { @downloader.start }
  end
end
