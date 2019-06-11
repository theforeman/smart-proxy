module Proxy::Templates
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    plugin :templates, ::Proxy::VERSION

    default_settings :template_url => nil

    validate_presence :template_url

    after_activation do
      loading_failed "missing :foreman_url: from configuration." unless Proxy::SETTINGS.foreman_url
    end
  end
end
