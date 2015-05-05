class ::Proxy::Provider
  include ::Proxy::Pluggable
  include ::Proxy::Log

  class << self
    attr_reader :main_module, :provider_factory_proc

    def main_module_settings
      @main_module_settings ||= ::Proxy::Plugins.find_plugin(main_module).settings
    end

    def plugin(plugin_name, aversion, attrs)
      @plugin_name = plugin_name.to_sym
      @version = aversion.chomp('-develop')
      @main_module = attrs[:main_module].to_sym rescue nil
      @provider_factory_proc = attrs[:factory]
      ::Proxy::Plugins.plugin_loaded(@plugin_name, @version, self)
    end
  end

  def main_module
    self.class.main_module
  end

  def provider_factory
    self.class.provider_factory_proc
  end

  def validate!
    super
    validate_provider_configuration!
  end

  # rubocop:disable Style/NonNilCheck
  def validate_provider_configuration!
    if (main_module != nil) ^ (provider_factory != nil)
      raise ::Proxy::PluginMisconfigured, "Error configuring provider '#{plugin_name}': ensure both 'main_module' and 'provider_factory' are defined"
    end
  end
end