class ::Proxy::RootPluginLoader < ::Proxy::DefaultModuleLoader
  # this is a special case: 'root' module doesn't have configuration file
  def load_configuration_file(settings_file)
    {}
  end

  # no need to log setting for this module as they aren't user-configurable and never change
  def log_used_settings(settings)
    # noop
  end
end
