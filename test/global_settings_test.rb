require 'test_helper'

class GlobalSettingsTest < Test::Unit::TestCase
  def test_default_values
    settings = ::Proxy::Settings::Global.new({})
    assert_equal Pathname.new(__dir__).join("..", "config", "settings.d").expand_path.to_s, settings.settings_directory
    assert_equal 8443, settings.https_port
    assert_equal "/var/log/foreman-proxy/proxy.log", settings.log_file
    assert_equal "INFO", settings.log_level
  end

  def test_normalize_setting
    how_to = { :test => ->(value) { value + 1 } }
    assert_equal 2, ::Proxy::Settings::Global.new({}).normalize_setting(:test, 1, how_to)
    assert_equal 3, ::Proxy::Settings::Global.new({}).normalize_setting(:test_2, 3, how_to)
  end

  def test_forman_url_is_normalized
    assert_equal "http://localhost:3000/",
                 ::Proxy::Settings::Global.new(:foreman_url => "http://localhost:3000").foreman_url
    assert_equal "http://localhost:3000/",
                 ::Proxy::Settings::Global.new(:foreman_url => "http://localhost:3000/").foreman_url
  end

  def test_bind_host_is_normalized
    assert_equal ['127.0.0.1'], ::Proxy::Settings::Global.new(:bind_host => '127.0.0.1').bind_host
    assert_equal ['127.0.0.1'], ::Proxy::Settings::Global.new(:bind_host => ['127.0.0.1']).bind_host
  end

  def test_ssl_private_key_default_without_credential
    settings = ::Proxy::Settings::Global.new({})
    Dir.mktmpdir do |tmpdir|
      ENV['CREDENTIALS_DIRECTORY'] = tmpdir
      assert_nil settings.ssl_private_key
    end
  end

  def test_ssl_private_key_default_with_credential
    settings = ::Proxy::Settings::Global.new({})
    Dir.mktmpdir do |tmpdir|
      ENV['CREDENTIALS_DIRECTORY'] = tmpdir
      path = File.join(tmpdir, 'server-key')
      FileUtils.touch(path)

      assert_equal path, settings.ssl_private_key
    end
  end

  def test_ssl_private_key_with_value
    settings = ::Proxy::Settings::Global.new({ssl_private_key: 'mykey'})
    Dir.mktmpdir do |tmpdir|
      ENV['CREDENTIALS_DIRECTORY'] = tmpdir
      path = File.join(tmpdir, 'server-key')
      FileUtils.touch(path)

      assert_equal 'mykey', settings.ssl_private_key
    end
  end
end
