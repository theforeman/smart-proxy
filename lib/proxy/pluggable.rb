module Proxy::Pluggable
  def self.included(base)
    base.send(:include, InstanceMethods)
    base.send(:extend, ClassMethods)
  end

  module InstanceMethods
    def plugin_name
      self.class.plugin_name
    end

    def version
      self.class.version
    end

    def bundler_group
      self.class.bundler_group_name || self.plugin_name
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

    def after_activation
      instance_eval(&self.class.after_activation_blk) if self.class.after_activation_blk
    end

    def validate!
      validate_dependencies!(self.class.dependencies)
      validate_prerequisites_enabled!(self.class.initialize_after)
    end

    def validate_prerequisites_enabled!(prerequisites)
      prerequisites.each do |p|
        if !(::Proxy::Plugins.find_plugin(p))
          raise ::Proxy::PluginMisconfigured, "Unable to find dependency '#{p}' of '#{plugin_name}'."
        end
        if !(::Proxy::Plugins.plugin_enabled?(p))
          raise ::Proxy::PluginMisconfigured, "Dependency '#{p}' of '#{plugin_name}' has not been enabled."
        end
      end
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

  module ClassMethods
    attr_reader :plugin_name, :version, :after_activation_blk, :plugin_default_settings, :bundler_group_name

    def after_activation(&blk)
      @after_activation_blk = blk
    end

    def dependencies
      @dependencies ||= []
    end

    def requires(plugin_name, version_spec)
      self.dependencies << ::Proxy::Dependency.new(plugin_name, version_spec.chomp('-develop'))
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

    def initialize_after(*module_names)
      @initialize_after ||= []
      if module_names.empty?
        to_return = @uses_provider ? @initialize_after + [settings.use_provider] : @initialize_after
        to_return.map(&:to_sym)
      else
        @initialize_after += module_names.map(&:to_sym)
      end
    end
  end
end
