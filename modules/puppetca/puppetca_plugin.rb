module Proxy::PuppetCa
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :ssldir => '/var/lib/puppet/ssl'

    uses_provider
    default_settings :use_provider => 'puppetca_hostname_whitelisting'

    load_classes ::Proxy::PuppetCa::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetCa::PluginConfiguration
    plugin :puppetca, ::Proxy::VERSION
  end
end
