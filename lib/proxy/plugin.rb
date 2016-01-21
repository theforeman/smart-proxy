require 'bundler_helper'

class ::Proxy::PluginNotFound < ::StandardError; end
class ::Proxy::PluginVersionMismatch < ::StandardError; end
class ::Proxy::PluginMisconfigured < ::StandardError; end
class ::Proxy::PluginProviderNotFound < ::StandardError; end
class ::Proxy::PluginLoadingAborted < ::StandardError; end

class ::Proxy::Dependency
  attr_reader :name, :version

  def initialize(aname, aversion)
    @name = aname.to_sym
    @version = aversion
  end
end

class ::Proxy::Plugins
  extend ::Proxy::Log

  class << self
    def plugin_loaded(a_name, a_version, a_class)
      self.loaded += [{:name => a_name, :version => a_version, :class => a_class, :enabled => false}]
    end

    def loaded
      @loaded ||= [] # {:name, :version, :class, :factory, :instance, :enabled}
    end

    def loaded=(an_array)
      @loaded = an_array
    end

    def update(updated_plugins)
      updated_plugins.each do |updated|
        loaded.delete_if {|p| p[:name] == updated[:name]}
        loaded << updated
      end
    end

    def plugin_enabled?(plugin_name)
      plugin = loaded.find {|p| p[:name] == plugin_name.to_sym}
      plugin.nil? ? false : !!plugin[:enabled]
    end

    def disable_plugin(plugin_name)
      logger.warn("::Proxy::Plugins.disable_plugin has been deprecated and will be removed from future versions of smart-proxy. Use Proxy::Pluggable#loading_failed instead.")
      plugin = loaded.find {|p| p[:name] == plugin_name.to_sym}
      plugin[:instance].fail
    end


    def find_plugin(plugin_name)
      p = loaded.find { |plugin| plugin[:name] == plugin_name.to_sym }
      return p[:class] if p
    end

    def enabled_plugins
      loaded.select {|p| p[:enabled] == true && p[:instance].is_a?(::Proxy::Plugin)}.map{|p| p[:instance]}
    end

    def find_provider(provider_name)
      provider = loaded.find {|p| p[:name] == provider_name.to_sym}
      raise ::Proxy::PluginProviderNotFound, "Provider '#{provider_name}' could not be found" if provider.nil? || !provider[:instance].is_a?(::Proxy::Provider)
      provider[:instance]
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
  extend ::Proxy::Log

  class << self
    attr_reader :get_http_rackup_path, :get_https_rackup_path, :get_uses_provider

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
      @get_uses_provider = true
    end
  end

  def validate_prerequisites_enabled!(all_plugins, prerequisites)
    prerequisites.each do |p|
      if !(all_plugins.find {|plugin| plugin[:name] == p.to_sym})
        raise ::Proxy::PluginMisconfigured, "Unable to find dependency '#{p}' of '#{plugin_name}'."
      end
      if !(all_plugins.find {|plugin| plugin[:name] == p.to_sym && plugin[:enabled] == true})
        raise ::Proxy::PluginMisconfigured, "Dependency '#{p}' of '#{plugin_name}' has not been enabled."
      end
    end
  end

  def validate!(all_plugins)
    validate_prerequisites_enabled!(all_plugins, [settings.use_provider]) if uses_provider?
    super(all_plugins)
  end

  def uses_provider?
    self.class.get_uses_provider
  end

  def http_rackup
    (self.class.http_enabled? && self.class.get_http_rackup_path) ? File.read(self.class.get_http_rackup_path) : ""
  end

  def https_rackup
    (self.class.https_enabled? && self.class.get_https_rackup_path) ? File.read(self.class.get_https_rackup_path) : ""
  end

  def configure_plugin(all_plugins)
    if settings.enabled
      logger.info("'#{plugin_name}' settings were initialized with default values: %s" % log_used_default_settings) unless settings.used_defaults.empty?
      validate!(all_plugins)
      ::Proxy::BundlerHelper.require_groups(:default, bundler_group)
      after_activation
      logger.info("Finished initialization of module '#{plugin_name}'")
      true
    else
      logger.info("'#{plugin_name}' module is disabled.")
      false
    end
  rescue Exception => e
    logger.error("Couldn't enable plugin #{plugin_name}: #{e}", e.backtrace)
    ::Proxy::LogBuffer::Buffer.instance.failed_module(plugin_name, e.message)
    false
  end
end
