module Proxy::Dns
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    uses_provider
    default_settings :use_provider => 'dns_nsupdate', :dns_ttl => 86_400
    expose_setting :use_provider
    plugin :dns, ::Proxy::VERSION

    load_classes ::Proxy::Dns::ConfigurationLoader
  end
end
