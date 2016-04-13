module Proxy::PuppetLegacy
  class Plugin < Proxy::Provider
    default_settings :puppet_ssl_ca => '/var/lib/puppet/ssl/certs/ca.pem', :puppet_conf => '/etc/puppet/puppet.conf', :use_cache => true

    plugin :puppet_proxy_legacy, ::Proxy::VERSION

    load_classes ::Proxy::PuppetLegacy::PluginConfiguration
    load_programmable_settings "::Proxy::PuppetLegacy::PluginConfiguration"
    load_validators :url => ::Proxy::Puppet::Validators::UrlValidator
    load_dependency_injection_wirings "::Proxy::PuppetLegacy::PluginConfiguration"

    validate_readable :puppet_conf
    validate :puppet_url, :url => true, :if => lambda {|settings| settings[:environments_retriever] != :config_file}
    validate :puppet_ssl_ca, :puppet_ssl_cert, :puppet_ssl_key, :file_readable => true, :if => lambda {|settings| settings[:environments_retriever] != :config_file}
  end
end
