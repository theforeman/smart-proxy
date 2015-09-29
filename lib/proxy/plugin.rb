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
  @@loaded = [] # {:name, :version, :class, :factory}
  @@enabled = {} # plugin_name => instance

  class << self
    def plugin_loaded(a_name, a_version, a_class)
      @@loaded += [{:name => a_name, :version => a_version, :class => a_class}]
    end

    def configure_loaded_plugins
      configuration_order = build_configuration_order(@@loaded)
      configuration_order.each { |plugin| plugin[:class].new.configure_plugin }
    end

    def build_configuration_order(loaded_plugins)
      plugins_only = loaded_plugins.select {|plugin| plugin[:class].ancestors.include?(::Proxy::Plugin)}
      configuration_order = []

      # FIX ME: config order currently is unaffected by provider prerequisites
      plugins_only.each do |plugin|
        next if configuration_order.include?(plugin)
        prerequisite_names = plugin[:class].initialize_after - configuration_order.map { |p| p[:name] }
        prerequisites = loaded_plugins.select {|p| prerequisite_names.include?(p[:name])}
        configuration_order = configuration_order + prerequisites + [plugin]
      end

      configuration_order
    end

    def plugin_enabled(plugin_name, instance)
      @@enabled[plugin_name.to_sym] = instance
    end

    def plugin_enabled?(plugin_name)
      !!@@enabled[plugin_name.to_sym]
    end

    def disable_plugin(plugin_name)
      @@enabled.delete(plugin_name.to_sym)
    end

    def find_plugin(plugin_name)
      p = @@loaded.find { |plugin| plugin[:name].to_s == plugin_name.to_s }
      return p[:class] if p
    end

    def enabled_plugins
      @@enabled.values.select {|instance| instance.is_a?(::Proxy::Plugin)}
    end

    def find_provider(provider_name)
      provider = @@enabled[provider_name.to_sym]
      raise ::Proxy::PluginProviderNotFound, "Provider '#{provider_name}' could not be found" if provider.nil? || !provider.is_a?(::Proxy::Provider)
      provider
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

    def uses_provider
      @uses_provider = true
    end
  end

  def http_rackup
    (self.class.http_enabled? && self.class.get_http_rackup_path) ? File.read(self.class.get_http_rackup_path) : ""
  end

  def https_rackup
    (self.class.https_enabled? && self.class.get_https_rackup_path) ? File.read(self.class.get_https_rackup_path) : ""
  end

  def configure_plugin
    if settings.enabled
      logger.info("'#{plugin_name}' settings were initialized with default values: %s" % log_used_default_settings) unless settings.used_defaults.empty?
      validate!
      ::Proxy::Plugins.plugin_enabled(plugin_name, self)
      ::Proxy::BundlerHelper.require_groups(:default, bundler_group)
      after_activation
      logger.info("Finished initialization of module '#{plugin_name}'")
    else
      logger.info("'#{plugin_name}' module is disabled.")
    end
  rescue Exception => e
    logger.error("Couldn't enable plugin #{plugin_name}: #{e}")
    logger.debug("#{e}:#{e.backtrace.join("\n")}")
    ::Proxy::Plugins.disable_plugin(plugin_name)
  end
end
