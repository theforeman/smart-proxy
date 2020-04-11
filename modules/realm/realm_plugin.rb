module Proxy::Realm
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))

    default_settings :use_provider => 'realm_freeipa'

    uses_provider
    load_classes ::Proxy::Realm::ConfigurationLoader

    plugin :realm, ::Proxy::VERSION
  end
end
