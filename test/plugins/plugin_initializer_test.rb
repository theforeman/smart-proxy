require 'test_helper'

class PluginInitializerTest < Test::Unit::TestCase
  class TestPlugin1 < Proxy::Plugin; plugin :plugin_1, "1.0"; default_settings :enabled => true; end
  class TestPlugin2 < Proxy::Plugin; plugin :plugin_2, "1.0"; default_settings :enabled => true; end
  class TestPlugin3 < Proxy::Plugin; plugin :plugin_3, "1.0"; uses_provider; default_settings :enabled => true, :use_provider => :plugin_4; end
  class TestPlugin4 < Proxy::Provider; plugin :plugin_4, "1.0"; default_settings :enabled => true; end
  class TestPlugin5 < Proxy::Plugin; plugin :plugin_5, "1.0"; default_settings :enabled => false; end

  CAP_PROC = proc{}
  CAP_LAMBDA = lambda{}
  class TestPlugin6 < Proxy::Plugin
    plugin :plugin_6, "1.0"
    capability(CAP_LAMBDA)
    capability(CAP_PROC)
    capability('foo')
    default_settings :enabled => true, :foo => :bar, :secret => :password
    expose_setting(:foo)
  end

  def test_initialize_plugins
    plugins = ::Proxy::Plugins.new
    plugins.update([{:name => :plugin_1, :version => '1.0', :class => TestPlugin1, :state => :uninitialized},
                    {:name => :plugin_2, :version => '1.0', :class => TestPlugin2, :state => :uninitialized},
                    {:name => :plugin_3, :version => '1.0', :class => TestPlugin3, :state => :uninitialized},
                    {:name => :plugin_4, :version => '1.0', :class => TestPlugin4, :state => :uninitialized},
                    {:name => :plugin_5, :version => '1.0', :class => TestPlugin5, :state => :uninitialized},
                    {:name => :plugin_6, :version => '1.0', :class => TestPlugin6, :state => :uninitialized}])

    initializer = ::Proxy::PluginInitializer.new(plugins)
    initializer.initialize_plugins

    # plugin and its provider should share di_container
    provider_and_plugin = plugins.loaded.select {|p| p[:name] == :plugin_3 || p[:name] == :plugin_4 }
    assert_equal 2, provider_and_plugin.size
    assert provider_and_plugin[0][:di_container] == provider_and_plugin[1][:di_container]

    # modules in 'uninitialized' state don't have di_containers, all others do
    all_but_uninitialized = plugins.loaded.select {|p| p[:name] != :plugin_5}
    assert all_but_uninitialized.all? {|p| p.has_key?(:di_container)}

    # filter out :di_container, can't use equality test with it
    loaded = plugins.loaded.map {|p| [:name, :version, :class, :state, :http_enabled, :capabilities, :settings, :https_enabled].inject({}) {|a, c| a[c] = p[c]; a}}
    assert_equal(
        [{:name => :plugin_1, :version => '1.0', :class => TestPlugin1, :state => :running, :http_enabled => true, :https_enabled => true,
          :settings => {}, :capabilities => []},
         {:name => :plugin_2, :version => '1.0', :class => TestPlugin2, :state => :running, :http_enabled => true, :https_enabled => true,
          :settings => {}, :capabilities => []},
         {:name => :plugin_3, :version => '1.0', :class => TestPlugin3, :state => :running, :http_enabled => true, :https_enabled => true,
          :settings => {"use_provider" => :plugin_4}, :capabilities => []},
         # :http_enabled and :https_enabled are not defined for providers
         {:name => :plugin_4, :version => '1.0', :class => TestPlugin4, :state => :running, :http_enabled => nil, :https_enabled => nil,
            :settings => nil, :capabilities => nil},
         {:name => :plugin_5, :version => '1.0', :class => TestPlugin5, :state => :disabled, :http_enabled => false, :https_enabled => false,
            :settings => {}, :capabilities => []},
         {:name => :plugin_6, :version => '1.0', :class => TestPlugin6, :state => :running, :http_enabled => true, :https_enabled => true,
            :settings=>{:foo=>:bar}, :capabilities => [CAP_LAMBDA, CAP_PROC, 'foo']}], loaded)
  end
end
