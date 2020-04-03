module Proxy::PuppetApi
  class Plugin < Proxy::Provider
    default_settings :puppet_ssl_ca => '/var/lib/puppet/ssl/certs/ca.pem', :api_timeout => 30

    plugin :puppet_proxy_puppet_api, ::Proxy::VERSION

    load_programmable_settings ::Proxy::PuppetApi::PluginConfiguration
    load_classes ::Proxy::PuppetApi::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetApi::PluginConfiguration

    validate :puppet_url, :url => true
    expose_setting :puppet_url
    validate_readable :puppet_ssl_ca, :puppet_ssl_cert, :puppet_ssl_key

    start_services :class_cache_initializer
  end
end
