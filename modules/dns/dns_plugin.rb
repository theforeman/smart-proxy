module Proxy::Dns
  class Plugin < ::Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    uses_provider
    default_settings :use_provider => 'dns_nsupdate', :dns_ttl => 86_400
    plugin :dns, ::Proxy::VERSION

    load_classes ::Proxy::Dns::ConfigurationLoader
  end
end
