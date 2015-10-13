class ::Proxy::RootPlugin < ::Proxy::Plugin
  plugin :foreman_proxy, ::Proxy::VERSION
  default_settings :enabled => true

  http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

  # this is a special case: 'root' module doesn't have configuration file
  def self.settings
    @settings ||= ::Proxy::Settings::Plugin.new(plugin_default_settings, {})
  end
end
