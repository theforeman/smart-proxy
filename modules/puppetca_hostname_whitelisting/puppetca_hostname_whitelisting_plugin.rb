module ::Proxy::PuppetCa::HostnameWhitelisting
  class Plugin < ::Proxy::Provider
    plugin :puppetca_hostname_whitelisting, ::Proxy::VERSION

    requires :puppetca, ::Proxy::VERSION
    default_settings :autosignfile => '/etc/puppet/autosign.conf'

    load_classes ::Proxy::PuppetCa::HostnameWhitelisting::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetCa::HostnameWhitelisting::PluginConfiguration
  end
end
