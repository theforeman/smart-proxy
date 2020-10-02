require 'test_helper'

class GlobalSettingsTest < Test::Unit::TestCase
  def test_default_values
    settings = ::Proxy::Settings::Global.new({})
    assert_equal Pathname.new(__dir__).join("..", "config", "settings.d").expand_path.to_s, settings.settings_directory
    assert_equal 8443, settings.https_port
    assert_equal "/var/log/foreman-proxy/proxy.log", settings.log_file
    assert_equal "INFO", settings.log_level
    assert_equal false, settings.daemon
    assert_equal "/var/run/foreman-proxy/foreman-proxy.pid", settings.daemon_pid
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

  def test_apply_argv_daemonize
    settings = ::Proxy::Settings::Global.new(daemon: false)
    settings.apply_argv(['--daemonize'])
    assert_equal true, settings.daemon
  end

  def test_apply_argv_no_daemonize
    settings = ::Proxy::Settings::Global.new(daemon: true)
    settings.apply_argv(['--no-daemonize'])
    assert_equal false, settings.daemon
  end
end
