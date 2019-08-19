module ::Proxy::Httpboot
  class PluginConfiguration
    def load_programmable_settings(settings)
      settings[:http_port] = Proxy::SETTINGS.http_port
      settings[:https_port] = Proxy::SETTINGS.https_port
      settings
    end
  end
end
