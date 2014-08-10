require 'bundler_helper'

class ::Proxy::PluginNotFound < ::StandardError; end
class ::Proxy::PluginVersionMismatch < ::StandardError; end

class ::Proxy::Dependency
  attr_reader :name, :version

  def initialize(aname, aversion)
    @name = aname.to_sym
    @version = aversion
  end
end

class ::Proxy::Plugins
  @@loaded = [] # {:name, :version, :class}
  @@enabled = {} # plugin_name => instance

  def self.plugin_loaded(a_name, a_version, a_class)
    @@loaded += [{:name => a_name, :version => a_version, :class => a_class}]
  end

  def self.configure_loaded_plugins
    @@loaded.each { |plugin| plugin[:class].new.configure_plugin }
  end

  def self.plugin_enabled(plugin_name, instance)
    @@enabled[plugin_name.to_sym] = instance
  end

  def self.disable_plugin(plugin_name)
    @@enabled.delete(plugin_name.to_sym)
  end

  def self.find_plugin(plugin_name)
    p = @@loaded.find { |plugin| plugin[:name].to_s == plugin_name.to_s }
    return p[:class] if p
  end

  def self.enabled_plugins
    @@enabled.values
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
  include ::Proxy::Log

  class << self
    attr_reader :plugin_name, :version, :after_activation_blk, :get_http_rackup_path, :get_https_rackup_path, :plugin_default_settings, :bundler_group_name

    def after_activation(&blk)
      @after_activation_blk = blk
    end

    def http_rackup_path(path)
      @get_http_rackup_path = path
    end

    def https_rackup_path(path)
      @get_https_rackup_path = path
    end

    def dependencies
      @dependencies ||= []
    end

    def requires(plugin_name, version_spec)
      self.dependencies << ::Proxy::Dependency.new(plugin_name, version_spec)
    end

    def bundler_group(name)
      @bundler_group_name = name
    end

    # relative to ::Proxy::SETTINGS.settings_directory
    def settings_file(apath = nil)
      if apath.nil?
        @settings_file || "#{plugin_name}.yml"
      else
        @settings = nil
        @settings_file = apath
      end
    end

    def default_settings(a_hash = {})
      @settings = nil
      @plugin_default_settings ||= {}
      @plugin_default_settings.merge!(a_hash)
    end

    def settings
      @settings ||= Proxy::Settings.load_plugin_settings(plugin_default_settings, settings_file)
    end

    def plugin(plugin_name, aversion)
      @plugin_name = plugin_name.to_sym
      @version = aversion.chomp('-develop')
      ::Proxy::Plugins.plugin_loaded(@plugin_name, @version, self)
    end
  end

  def plugin_name
    self.class.plugin_name
  end

  def version
    self.class.version
  end

  def bundler_group
    self.class.bundler_group_name || self.plugin_name
  end

  def http_rackup
    self.class.get_http_rackup_path.nil? ? "" : File.read(self.class.get_http_rackup_path)
  end

  def https_rackup
    self.class.get_https_rackup_path.nil? ? "" : File.read(self.class.get_https_rackup_path)
  end

  def settings
    self.class.settings
  end

  def log_used_default_settings
    settings.defaults.select {|k,v| settings.used_defaults.include?(k)}.
      inject({}) {|acc, c| acc[c[0].to_s] = c[1]; acc}.
      sort.
      collect {|c| ":#{c[0]}: #{c[1]}"}.
      join(", ")
  end

  def configure_plugin
    if settings.enabled
      logger.info("'#{plugin_name}' settings were initialized with default values: %s" % log_used_default_settings) unless settings.used_defaults.empty?
      validate_dependencies!(self.class.dependencies)
      ::Proxy::Plugins.plugin_enabled(plugin_name, self)
      ::Proxy::BundlerHelper.require_groups(:default, bundler_group)
      after_activation
    else
      logger.info("'#{plugin_name}' module is disabled.")
    end
  rescue Exception => e
    logger.error("Couldn't enable plugin #{plugin_name}: #{e}:#{e.backtrace.join('/n')}")
    ::Proxy::Plugins.disable_plugin(plugin_name)
  end

  def after_activation
    self.class.after_activation_blk.call if self.class.after_activation_blk
  end

  def validate_dependencies!(dependencies)
    dependencies.each do |dep|
      plugin = ::Proxy::Plugins.find_plugin(dep.name)
      raise ::Proxy::PluginNotFound, "Plugin '#{dep.name}' required by plugin '#{plugin_name}' could not be found." unless plugin
      unless ::Gem::Dependency.new('', dep.version).match?('', plugin.version)
        raise ::Proxy::PluginVersionMismatch, "Available version '#{plugin.version}' of plugin '#{dep.name}' doesn't match version '#{dep.version}' required by plugin '#{plugin_name}'"
      end
    end
  end
end
