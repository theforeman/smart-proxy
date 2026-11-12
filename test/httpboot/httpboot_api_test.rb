require 'test_helper'
require 'tempfile'
require 'httpboot/httpboot_plugin'
require 'httpboot/httpboot_api'

ENV['RACK_ENV'] = 'test'

class HttpbootApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    @app ||= Proxy::HttpbootApi.new
  end

  def setup
    @now = 0.0
    @limiter = Proxy::Httpboot::RequestLimiter.new(clock: -> { @now })
    Proxy::HttpbootApi.stubs(:request_limiter).returns(@limiter)
    @tempdir = Dir.mktmpdir 'httpboot-test'
    FileUtils.touch "#{@tempdir}/valid_file"
    Dir.mkdir "#{@tempdir}/valid_dir"
    Dir.mkdir "#{@tempdir}/valid_dir/nested_dir"
    FileUtils.ln_s "#{@tempdir}/valid_file", "#{@tempdir}/valid_symlink"
    FileUtils.ln_s "#{@tempdir}/does_not_exist", "#{@tempdir}/invalid_symlink"
    Proxy::Httpboot::Plugin.load_test_settings(root_dir: @tempdir, request_limit_5m: 3)
  end

  def teardown
    FileUtils.rm_rf(@tempdir) if @tempdir =~ /httpboot-test/
  end

  def test_valid_file
    result = get "/valid_file"
    assert_equal 200, last_response.status
    assert_equal '', result.body
  end

  def test_valid_dir
    result = get "/valid_dir"
    assert_equal 403, last_response.status
    assert_equal 'Directory listing not allowed', result.body
  end

  def test_nested_directory_listing_is_disabled
    get "/valid_dir/nested_dir"
    assert_equal 403, last_response.status
    assert_equal 'Directory listing not allowed', last_response.body
  end

  def test_valid_symlink
    result = get "/valid_symlink"
    assert_equal 200, last_response.status
    assert_equal '', result.body
  end

  def test_invalid_symlink
    result = get "/invalid_symlink"
    assert_equal 404, last_response.status
    assert_equal 'Not found', result.body
  end

  def test_empty_path
    result = get "/"
    assert_equal 403, last_response.status
    assert_equal 'Invalid or empty path', result.body
  end

  def test_dangerous_symlink
    another_dir = Dir.mktmpdir 'httpboot-test2'
    FileUtils.touch "#{another_dir}/secure_file"
    FileUtils.ln_s "#{another_dir}/secure_file", "#{@tempdir}/dangerous_symlink"
    result = get "/dangerous_symlink"
    assert_equal 403, last_response.status
    assert_equal 'Invalid or empty path', result.body
  ensure
    FileUtils.rm_rf(another_dir) if another_dir =~ /httpboot-test/
  end

  def test_limit_counts_missing_files_and_uses_sliding_window
    get '/missing1', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 404, last_response.status

    @now = 100
    get '/missing2', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 404, last_response.status

    @now = 200
    get '/missing3', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 404, last_response.status

    @now = 299.9
    get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 429, last_response.status

    @now = 300
    get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 200, last_response.status

    @now = 399.9
    get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 429, last_response.status

    @now = 400
    get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 200, last_response.status
  end

  def test_limit_is_per_remote_ip_and_ignores_forwarded_header
    3.times do |index|
      get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1', 'HTTP_X_FORWARDED_FOR' => "192.0.2.#{index + 2}"
      assert_equal 200, last_response.status
    end

    get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1', 'HTTP_X_FORWARDED_FOR' => '192.0.2.5'
    assert_equal 429, last_response.status

    get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.2'
    assert_equal 200, last_response.status
  end

  def test_head_requests_count_toward_limit
    3.times do
      head '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
      assert_equal 200, last_response.status
    end

    get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 429, last_response.status
  end

  def test_limit_is_shared_between_efi_and_httpboot_mounts
    @app = Rack::URLMap.new('/EFI' => Proxy::HttpbootApi.new, '/httpboot' => Proxy::HttpbootApi.new)

    2.times do
      get '/EFI/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
      assert_equal 200, last_response.status
    end

    get '/httpboot/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 200, last_response.status

    get '/httpboot/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 429, last_response.status
  end

  def test_limit_is_synchronized_between_threads
    limiter = Proxy::Httpboot::RequestLimiter.new(clock: -> { 0 })
    allowed = Array.new(20) { Thread.new { limiter.allow?('192.0.2.1', 3) } }.map(&:value)

    assert_equal 3, allowed.count(true)
    assert_equal 17, allowed.count(false)
  end

  def test_default_request_limit
    assert_equal 300, Proxy::Httpboot::Plugin.plugin_default_settings[:request_limit_5m]
  end

  def test_zero_disables_request_limit
    Proxy::Httpboot::Plugin.load_test_settings(root_dir: @tempdir, request_limit_5m: 0)

    5.times do
      get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
      assert_equal 200, last_response.status
    end

    Proxy::Httpboot::Plugin.load_test_settings(root_dir: @tempdir, request_limit_5m: 1)
    get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 200, last_response.status
    get '/valid_file', {}, 'REMOTE_ADDR' => '192.0.2.1'
    assert_equal 429, last_response.status
  end

  def test_request_limit_must_be_a_non_negative_integer
    settings = Proxy::Httpboot::Plugin.programmable_settings.load_programmable_settings(request_limit_5m: 0)
    assert_equal 0, settings[:request_limit_5m]

    [-1, '300', nil].each do |limit|
      assert_raise(ArgumentError) do
        Proxy::Httpboot::Plugin.programmable_settings.load_programmable_settings(request_limit_5m: limit)
      end
    end
  end
end
