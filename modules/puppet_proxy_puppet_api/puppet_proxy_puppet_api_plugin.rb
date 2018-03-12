module Proxy::PuppetApi
  class Plugin < Proxy::Provider
    default_settings :puppet_ssl_ca => '/var/lib/puppet/ssl/certs/ca.pem', :api_timeout => 30,
                     :classes_counter_update_frequency => 60 * 60, :classes_counter_timeout_interval => 10 * 60,
                     :max_number_of_cached_environments => 100

    plugin :puppet_proxy_puppet_api, ::Proxy::VERSION

    load_validators :url => ::Proxy::Puppet::Validators::UrlValidator
    load_programmable_settings ::Proxy::PuppetApi::PluginConfiguration
    load_classes ::Proxy::PuppetApi::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetApi::PluginConfiguration

    validate :puppet_url, :url => true
    validate_readable :puppet_ssl_ca, :puppet_ssl_cert, :puppet_ssl_key

    start_services :environment_classes_counter
  end
end
