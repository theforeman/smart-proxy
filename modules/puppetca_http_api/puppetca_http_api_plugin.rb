require 'puppet_proxy_common/custom_validators'

module ::Proxy
  module PuppetCa
    module PuppetcaHttpApi
      class Plugin < ::Proxy::Provider
        plugin :puppetca_http_api, ::Proxy::VERSION

        default_settings :puppet_ssl_ca => '/etc/puppetlabs/puppet/ssl/certs/ca.pem'

        load_validators :url => ::Proxy::Puppet::Validators::UrlValidator
        requires :puppetca, ::Proxy::VERSION

        validate :puppet_url, :url => true
        validate_readable :puppet_ssl_ca, :puppet_ssl_cert, :puppet_ssl_key

        load_classes ::Proxy::PuppetCa::PuppetcaHttpApi::PluginConfiguration
        load_dependency_injection_wirings ::Proxy::PuppetCa::PuppetcaHttpApi::PluginConfiguration
      end
    end
  end
end
