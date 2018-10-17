module ::Proxy::PuppetCa::PuppetcaPuppetCert
  class Plugin < ::Proxy::Provider
    plugin :puppetca_puppet_cert, ::Proxy::VERSION

    requires :puppetca, ::Proxy::VERSION
    default_settings :ssldir => '/var/lib/puppet/ssl'

    load_classes ::Proxy::PuppetCa::PuppetcaPuppetCert::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetCa::PuppetcaPuppetCert::PluginConfiguration
  end
end
