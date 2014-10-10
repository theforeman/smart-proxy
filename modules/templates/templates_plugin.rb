module Proxy::Templates
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    plugin :templates, ::Proxy::VERSION

    after_activation do
      unless Proxy::SETTINGS.foreman_url
        logger.warn "missing :foreman_url: from configurations. 'templates' module is disabled"
        ::Proxy::Plugins.disable_plugin(:templates)
      end

      unless Proxy::Templates::Plugin.settings.template_url
        logger.warn "missing :templates_url: from configurations. 'templates' module is disabled"
        ::Proxy::Plugins.disable_plugin(:templates)
      end
    end
  end
end
