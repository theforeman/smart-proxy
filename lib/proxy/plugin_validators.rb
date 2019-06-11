module ::Proxy::PluginValidators
  class Base
    def initialize(plugin, setting_name, params, predicate)
      @plugin = plugin
      @setting_name = setting_name.to_sym
      @params = params
      @predicate = predicate
    end

    def required_setting?
      @plugin.plugin_default_settings.has_key?(@setting_name) && !@plugin.plugin_default_settings[@setting_name].nil?
    end

    def evaluate_predicate(settings)
      return true if @predicate.nil?
      return @predicate.call(settings)
    end

    def evaluate_predicate_and_validate!(settings)
      return true unless evaluate_predicate(settings)
      validate!(settings)
    end
  end

  class FileReadable < Base
    def validate!(settings)
      setting_value = settings[@setting_name]
      return true if !required_setting? && setting_value.nil? # validate optional settings only if they aren't nil
      raise ::Proxy::Error::ConfigurationError, "File at '#{setting_value}' defined in '#{@setting_name}' parameter doesn't exist or is unreadable" unless File.readable?(setting_value)
      true
    end
  end

  class Presence < Base
    def validate!(settings)
      setting_value = settings[@setting_name]

      empty_value = setting_value.nil?
      empty_value ||= setting_value.empty? if setting_value.is_a?(String)

      raise ::Proxy::Error::ConfigurationError, "Parameter '#{@setting_name}' is expected to have a non-empty value" if empty_value
      true
    end
  end
end
