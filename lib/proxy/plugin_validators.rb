module ::Proxy::PluginValidators
  class FileReadable
    def initialize(plugin, setting_name)
      @plugin = plugin
      @setting_name = setting_name
    end

    def validate!
      setting_value = @plugin.settings.send(@setting_name)
      raise ::Proxy::Error::ConfigurationError, "File at '#{setting_value}' defined in '#{@setting_name}' parameter doesn't exist or is unreadable" unless File.readable?(setting_value)
      true
    end
  end
end
