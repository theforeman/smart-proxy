module ::Proxy::PluginValidators
  class Base
    def initialize(plugin, setting_name)
      @plugin = plugin
      @setting_name = setting_name
    end

    def required_setting?
      @plugin.plugin_default_settings.has_key?(@setting_name)
    end

    def setting_value
      @plugin.settings.send(@setting_name)
    end
  end

  class FileReadable < Base
    def validate!
      return true if !required_setting? && setting_value.nil? # validate optional settings only if they aren't nil
      raise ::Proxy::Error::ConfigurationError, "File at '#{setting_value}' defined in '#{@setting_name}' parameter doesn't exist or is unreadable" unless File.readable?(setting_value)
      true
    end
  end

  class Presence < Base
    def validate!
      value_empty = setting_value.nil?
      value_empty ||= setting_value.empty? if setting_value.is_a?(String)
      raise ::Proxy::Error::ConfigurationError, "Parameter '#{@setting_name}' is expected to have a non-empty value" if value_empty
      true
    end
  end
end
