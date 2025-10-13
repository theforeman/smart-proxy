class ::Proxy::RootPlugin < Proxy::Plugin
  plugin :foreman_proxy, ::Proxy::VERSION
  default_settings :enabled => true

  rackup_path File.expand_path("http_config.ru", __dir__)

  override_module_loader_class ::Proxy::RootPluginLoader
end
