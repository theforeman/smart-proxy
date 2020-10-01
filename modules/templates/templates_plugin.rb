module Proxy::Templates
  class Plugin < ::Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    plugin :templates, ::Proxy::VERSION

    validate :template_url, url: true
    expose_setting :template_url

    after_activation do
      loading_failed "missing :foreman_url: from configuration." unless Proxy::SETTINGS.foreman_url
    end
  end
end
