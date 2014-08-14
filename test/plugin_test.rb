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
end
