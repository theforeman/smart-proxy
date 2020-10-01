module Proxy::Realm
  class Plugin < ::Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    default_settings :use_provider => 'realm_freeipa'

    uses_provider
    load_classes ::Proxy::Realm::ConfigurationLoader

    plugin :realm, ::Proxy::VERSION
  end
end
