require 'test_helper'
require 'tempfile'
require 'tftp/tftp_plugin'
require 'tftp/tftp_system_image_api'

ENV['RACK_ENV'] = 'test'

class TftpBootImageApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::TFTP::SystemImageApi.new
  end

  def setup
    @tempdir = Dir.mktmpdir 'tftpsystemimage-test'
    @osdir = Dir.mktmpdir nil, @tempdir
    @osdir_base = File.basename @osdir
    FileUtils.touch "#{@osdir}/valid_file"
    FileUtils.ln_s "#{@osdir}/valid_file", "#{@tempdir}/valid_symlink"
    FileUtils.ln_s "#{@tempdir}/does_not_exist", "#{@tempdir}/invalid_symlink"
    Proxy::TFTP::Plugin.load_test_settings(enable_system_image: true, system_image_root: @tempdir)
  end

  def teardown
    FileUtils.rm_rf(@tempdir) if @tempdir =~ /tftpsystemimage-test/
  end

  def test_valid_file
    result = get "/#{@osdir_base}/valid_file"
    assert_equal 200, last_response.status
    assert_equal '', result.body
  end

  def test_valid_dir
    result = get "/#{@osdir_base}/"
    assert_equal 403, last_response.status
    assert_equal 'Directory listing not allowed', result.body
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
    another_dir = Dir.mktmpdir 'tftpsystemimage-test2'
    FileUtils.touch "#{another_dir}/secure_file"
    FileUtils.ln_s "#{another_dir}/secure_file", "#{@tempdir}/dangerous_symlink"
    result = get "/dangerous_symlink"
    assert_equal 403, last_response.status
    assert_equal 'Invalid or empty path', result.body
  ensure
    FileUtils.rm_rf(another_dir) if another_dir =~ /tftpimageboot-test/
  end
end
