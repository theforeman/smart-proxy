class ::Proxy::RootPlugin < ::Proxy::Plugin
  plugin :foreman_proxy, ::Proxy::VERSION
  default_settings :enabled => true

  http_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))

  override_module_loader_class ::Proxy::RootPluginLoader
end
