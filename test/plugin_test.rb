require 'test_helper'

class Proxy::Plugin
  class << self
    attr_writer :settings
  end
end

class PluginTest < Test::Unit::TestCase
  def test_log_used_default_settings
    eval "class TestPlugin1 < Proxy::Plugin; end"
    plugin = TestPlugin1.new
    plugin.class.settings = ::Proxy::Settings::Plugin.new({:a => 'a', :b => 'b'}, {})

    assert_equal ':a: a, :b: b, :enabled: false', plugin.log_used_default_settings
  end

  def test_http_rackup_returns_empty_string_with_missing_rackup_path
    eval "class TestPlugin2 < Proxy::Plugin; end"
    assert_equal "", TestPlugin2.new.http_rackup
    assert_equal "", TestPlugin2.new.https_rackup
  end
end
