require 'bundler_helper'

class ::Proxy::PluginNotFound < ::StandardError; end
class ::Proxy::PluginVersionMismatch < ::StandardError; end
class ::Proxy::PluginMisconfigured < ::StandardError; end
class ::Proxy::PluginProviderNotFound < ::StandardError; end

class ::Proxy::Dependency
  attr_reader :name, :version

  def initialize(aname, aversion)
    @name = aname.to_sym
    @version = aversion
  end
end

class ::Proxy::Plugins
  @@loaded = [] # {:name, :version, :class, :main_module, :factory}
  @@enabled = {} # plugin_name => instance

  class << self
    def plugin_loaded(a_name, a_version, a_class)
      @@loaded += [{:name => a_name, :version => a_version, :class => a_class}]
    end

    def configure_loaded_plugins
      @@loaded.each { |plugin| plugin[:class].new.configure_plugin }
    end

    def plugin_enabled(plugin_name, instance)
      @@enabled[plugin_name.to_sym] = instance
    end

    def disable_plugin(plugin_name)
      @@enabled.delete(plugin_name.to_sym)
    end

    def find_plugin(plugin_name)
      p = @@loaded.find { |plugin| plugin[:name].to_s == plugin_name.to_s }
      return p[:class] if p
    end

    def enabled_plugins
      plugins = @@enabled.select {|name, instance| instance.is_a?(::Proxy::Plugin)}
      plugins.values
    end

    def find_provider_factory(provider_name)
      providers = @@enabled.select {|name, instance| instance.is_a?(::Proxy::Provider)}
      provider = providers[provider_name.to_sym]
      raise ::Proxy::PluginProviderNotFound, "Provider '#{provider_name}' could not be found" unless provider
      provider.provider_factory
    end
  end
end

#
# example of plugin API
#
# class ExamplePlugin < ::Proxy::Plugin
#  plugin :example, "1.2.3"
#  config_file "example.yml"
#  http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__)) # note no https rackup path, module will not be available over https
#  requires :foreman_proxy, ">= 1.5.develop"
#  requires :another_plugin, "~> 1.3.0"
#  default_settings :first => 'first', :second => 'second'
#  after_activation { call_that }
#  bundler_group :blah
# end
#
class ::Proxy::Plugin
  include ::Proxy::Pluggable
  include ::Proxy::Log

  class << self
    attr_reader :get_http_rackup_path, :get_https_rackup_path

    def http_enabled?
      [true,'http'].include?(self.settings.enabled)
    end

    def http_rackup_path(path)
      @get_http_rackup_path = path
    end

    def https_enabled?
      [true,'https'].include?(self.settings.enabled)
    end

    def https_rackup_path(path)
      @get_https_rackup_path = path
    end

    def plugin(plugin_name, aversion)
      @plugin_name = plugin_name.to_sym
      @version = aversion.chomp('-develop')
      ::Proxy::Plugins.plugin_loaded(@plugin_name, @version, self)
    end
  end

  def http_rackup
    (self.class.http_enabled? && self.class.get_http_rackup_path) ? File.read(self.class.get_http_rackup_path) : ""
  end

  def https_rackup
    (self.class.https_enabled? && self.class.get_https_rackup_path) ? File.read(self.class.get_https_rackup_path) : ""
  end
end
