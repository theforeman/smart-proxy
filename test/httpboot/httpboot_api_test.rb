require 'test_helper'
require 'tempfile'
require 'httpboot/httpboot_plugin'
require 'httpboot/httpboot_api'

ENV['RACK_ENV'] = 'test'

class HttpbootApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::HttpbootApi.new
  end

  def setup
    @tempdir = Dir.mktmpdir 'httpboot-test'
    FileUtils.touch "#{@tempdir}/valid_file"
    Dir.mkdir "#{@tempdir}/valid_dir"
    Dir.mkdir "#{@tempdir}/grub2"
    FileUtils.touch "#{@tempdir}/grub2/valid_file"
    FileUtils.touch "#{@tempdir}/grub2/grub.cfg"
    FileUtils.touch "#{@tempdir}/grub2/grub.cfg-00-01-02-03-04-05-06"
    FileUtils.ln_s "#{@tempdir}/valid_file", "#{@tempdir}/valid_symlink"
    FileUtils.ln_s "#{@tempdir}/does_not_exist", "#{@tempdir}/invalid_symlink"
    Proxy::Httpboot::Plugin.load_test_settings(root_dir: @tempdir)
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

  def test_valid_file_in_grub2
    env = { 'REQUEST_PATH' => "/grub2/valid_file" }
    result = get "/irrelevant", {}, env
    assert_equal 200, last_response.status
    assert_equal '', result.body
  end

  def test_grubcfg_in_grub2
    env = { 'REQUEST_PATH' => "/grub.cfg" }
    result = get "/irrelevant", {}, env
    assert_equal 200, last_response.status
    assert_equal '', result.body
  end

  def test_grubcfg_with_mac_in_grub2
    env = { 'REQUEST_PATH' => "/grub.cfg-00-01-02-03-04-05-06" }
    result = get "/irrelevant", {}, env
    assert_equal 200, last_response.status
    assert_equal '', result.body
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
end
