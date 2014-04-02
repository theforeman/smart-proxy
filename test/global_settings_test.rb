require 'test_helper'

class GlobalSettingsTest < Test::Unit::TestCase
  def test_default_values
    settings = ::Proxy::Settings::Global.new({})
    assert_equal Pathname.new(__FILE__).join("..","..","config","settings.d").expand_path.to_s, settings.settings_directory
    assert_equal 8443, settings.https_port
    assert_equal "/var/log/foreman-proxy/proxy.log", settings.log_file
    assert_equal "ERROR", settings.log_level
    assert_equal false, settings.daemon
    assert_equal "/var/run/foreman-proxy/foreman-proxy.pid", settings.daemon_pid
  end
end
