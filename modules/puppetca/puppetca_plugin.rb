module Proxy::PuppetCa
  class Plugin < ::Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    uses_provider
    default_settings :use_provider => 'puppetca_hostname_whitelisting'

    load_classes ::Proxy::PuppetCa::PluginConfiguration
    load_programmable_settings ::Proxy::PuppetCa::PluginConfiguration

    plugin :puppetca, ::Proxy::VERSION
  end
end
