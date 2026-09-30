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
      '--fail',
      "--connect-timeout", "10",
      "--retry", "3",
      "--retry-delay", "10",
      "--max-time", "3600",
      "--remote-time",
      "--time-cond", "dst",
      "--write-out", "Task done, result: %{http_code}, size downloaded: %{size_download}b, speed: %{speed_download}b/s, time: %{time_total}ms",
      "--output", "dst",
      "--location", "src"
    ]
    assert_equal expected, Proxy::HttpDownload.new('src', 'dst').command
  end

  def test_unconditional_call_does_not_compare_destination_timestamp
    command = Proxy::HttpDownload.new('src', 'dst', conditional: false).command
    assert_not_include command, '--time-cond'
  end

  def test_regular_call_with_ssl_verify
    expected = [
      "/usr/bin/curl",
      "--silent", "--show-error",
      '--fail',
      "--connect-timeout", "10",
      "--retry", "3",
      "--retry-delay", "10",
      "--max-time", "3600",
      "--remote-time",
      "--time-cond", "dst",
      "--write-out", "Task done, result: %{http_code}, size downloaded: %{size_download}b, speed: %{speed_download}b/s, time: %{time_total}ms",
      "--output", "dst",
      "--location", "src"
    ]
    assert_equal expected, Proxy::HttpDownload.new('src', 'dst', verify_server_cert: true).command
  end

  def test_http_preflight_follows_redirects
    stub_request(:head, 'https://example.test/archive').to_return(status: 302, headers: { 'Location' => '/final' })
    stub_request(:head, 'https://example.test/final').to_return(status: 200)
    Proxy::HttpDownload.any_instance.stubs(:which).returns('/usr/bin/true')

    Dir.mktmpdir do |tmpdir|
      download = Proxy::HttpDownload.new('https://example.test/archive', File.join(tmpdir, 'archive'), preflight: true)
      assert_not_requested(:head, 'https://example.test/archive')
      assert_equal 0, download.start.join
    end

    assert_requested(:head, 'https://example.test/archive')
    assert_requested(:head, 'https://example.test/final')
  end

  def test_http_preflight_sets_ssl_verification_mode
    {
      true => OpenSSL::SSL::VERIFY_PEER,
      false => OpenSSL::SSL::VERIFY_NONE,
    }.each do |verify_server_cert, expected_mode|
      source = "https://example.test/#{verify_server_cert}"
      stub_request(:head, source).to_return(status: 200)
      Net::HTTP.any_instance.expects(:verify_mode=).with(expected_mode).once
      download = Proxy::HttpDownload.new(source, 'dst')

      response = download.send(:preflight_http, source, @timeout, verify_server_cert)

      assert_nil response
    end
  end

  def test_http_download_rejects_url_credentials
    source = 'https://user:p%40ss@example.test/archive'
    error = assert_raises(ArgumentError) do
      Proxy::HttpDownload.new(source, 'dst', preflight: false)
    end

    assert_equal 'HTTP download URLs must not include a username or password', error.message
  end

  def test_http_preflight_explains_when_head_is_unsupported
    [405, 501].each do |status|
      source = "https://example.test/#{status}"
      stub_request(:head, source).to_return(status: status)
      download = Proxy::HttpDownload.new(source, 'dst')

      error = assert_raises(Proxy::HttpDownload::PreflightError) do
        download.send(:preflight_http, source, @timeout, true)
      end
      assert_match(/#{status}/, error.message)
      assert_match(/tftp_http_download_preflight to false/, error.message)
    end
  end

  def test_http_preflight_can_be_disabled
    Proxy::HttpDownload.new('https://example.test/archive', 'dst', preflight: false)

    assert_not_requested(:head, 'https://example.test/archive')
  end

  def test_should_skip_download_if_one_is_in_progress
    Dir.mktmpdir do |tmpdir|
      Proxy::FileLock.try_locking("#{tmpdir}/.dst.lock")
      assert_equal false, Proxy::HttpDownload.new('src', "#{tmpdir}/dst").start
    end
  end
end

class HttpDownloadsIntegrationTest < Test::Unit::TestCase
  def setup
    @server = WEBrick::HTTPServer.new(Port: 0)
    @server.mount_proc '/200' do |req, res|
      res.body = 'Hello, world!'
    end
    @thread = Thread.new { @server.start }
  end

  def teardown
    @thread.exit
    @thread.join
  end

  def test_retrieving_found
    src = "http://localhost:#{@server.config[:Port]}/200"

    dest = Tempfile.new('found')
    path = dest.path
    dest.unlink

    thread = Proxy::HttpDownload.new(src, path).start
    thread.join

    assert File.exist?(path)
  ensure
    FileUtils.rm_f(path)
  end

  def test_retrieving_not_found
    src = "http://localhost:#{@server.config[:Port]}/404"

    dest = Tempfile.new('not-found')
    path = dest.path
    dest.unlink

    thread = Proxy::HttpDownload.new(src, path).start
    thread.join

    assert !File.exist?(path)
  ensure
    FileUtils.rm_f(path)
  end
end
