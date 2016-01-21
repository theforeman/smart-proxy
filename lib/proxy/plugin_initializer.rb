class ::Proxy::PluginInitializer
  def initialize_plugins(loaded_plugins)
    instantiated_plugins = instantiate_plugins(loaded_plugins)
    in_configuration_order = build_configuration_order(instantiated_plugins)
    configure_plugins(in_configuration_order, instantiated_plugins)
  end

  def instantiate_plugins(loaded_plugins)
    loaded_plugins.dup.map {|p| p.update(:instance => p[:class].new)}
  end

  def build_configuration_order(instantiated_plugins)
    enabled_plugins = instantiated_plugins.select {|plugin| plugin[:class].ancestors.include?(::Proxy::Plugin) && plugin[:instance].settings.enabled}
    configuration_order = []

    enabled_plugins.each do |plugin|
      if plugin[:instance].uses_provider?
        provider_name = plugin[:instance].settings.use_provider
        configuration_order = configuration_order + (instantiated_plugins.select {|p| p[:name] == provider_name.to_sym})
      end
      configuration_order = configuration_order + [plugin]
    end

    configuration_order
  end

  def configure_plugins(ordered_plugins, instantiated_plugins)
    to_return = instantiated_plugins.dup
    ordered_plugins.each do |plugin|
      to_update = to_return.find {|p| p == plugin}
      to_update.update(:enabled => true) if to_update[:instance].configure_plugin(to_return)
    end

    to_return
  end
end
