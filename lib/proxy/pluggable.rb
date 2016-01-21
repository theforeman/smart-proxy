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

    def validate!(all_plugins)
      validate_dependencies!(all_plugins, self.class.dependencies)
      execute_validators(self.class.plugin_default_settings.keys.map {|k| ::Proxy::PluginValidators::Presence.new(self.class, k)})
      execute_validators(self.class.validators)
    end

    def execute_validators(validators)
      validators.each { |validator| validator.validate! }
    end

    def validate_dependencies!(all_plugins, dependencies)
      dependencies.each do |dep|
        plugin = all_plugins.find {|p| p[:name] == dep.name}
        raise ::Proxy::PluginNotFound, "Plugin '#{dep.name}' required by plugin '#{plugin_name}' could not be found." unless plugin
        unless ::Gem::Dependency.new('', dep.version).match?('', self.class.cleanup_version(plugin[:instance].version))
          raise ::Proxy::PluginVersionMismatch, "Available version '#{plugin[:instance].version}' of plugin '#{dep.name}' doesn't match version '#{dep.version}' required by plugin '#{plugin_name}'"
        end
      end
    end

    def loading_failed(message)
      raise ::Proxy::PluginLoadingAborted, message
    end
  end

  module ClassMethods
    attr_reader :plugin_name, :version, :after_activation_blk, :bundler_group_name

    # Methods below define DSL for defining plugins

    def after_activation(&blk)
      @after_activation_blk = blk
    end

    def requires(plugin_name, version_spec)
      self.dependencies << ::Proxy::Dependency.new(plugin_name, cleanup_version(version_spec))
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

    def initialize_after(*module_names)
      raise "#{plugin_name}: 'initialize_after' method has been removed."
    end

    def validate_readable(*settings)
      # Passing in plugin class and setting name is a bit awkward, but we need to delay the loading of module settings
      # until after module's Plugin/Provider class has been loaded (to preserve order-independence of statements used in
      # the class body of the Plugin.)
      settings.each { |setting| validators << ::Proxy::PluginValidators::FileReadable.new(self, setting) }
    end

    def validate_presence(*settings)
      settings.each { |setting| validators << ::Proxy::PluginValidators::Presence.new(self, setting) }
    end

    # End of DSL

    def dependencies
      @dependencies ||= []
    end

    def plugin_default_settings
      @plugin_default_settings ||= {}
    end

    def settings
      @settings ||= Proxy::Settings.load_plugin_settings(plugin_default_settings, settings_file)
    end

    def validators
      @validators ||= []
    end

    def cleanup_version(version)
      version.chomp('-develop').sub(/\-RC\d+$/, '')
    end
  end
end
