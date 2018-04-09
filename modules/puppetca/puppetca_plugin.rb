module Proxy::PuppetCa
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :ssldir => '/var/lib/puppet/ssl', :sign_all => false

    plugin :puppetca, ::Proxy::VERSION

    load_classes ::Proxy::PuppetCa::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetCa::PluginConfiguration
  end
end
