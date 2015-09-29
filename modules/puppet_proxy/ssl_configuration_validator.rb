require 'puppet_proxy/runtime_configuration'

module Proxy::Puppet
  class SslConfigurationValidator
    include Proxy::Puppet::RuntimeConfiguration

    def validate_ssl_paths!
      return true if environments_retriever == :config_file

      ssl_ca   = Proxy::Puppet::Plugin.settings.puppet_ssl_ca

      check_file(ssl_ca, "puppet CA certificate at '#{ssl_ca}' defined in ':puppet_ssl_ca' setting doesn't exist or is unreadable")
      check_file(ssl_cert, "puppet client certificate at #{ssl_cert} defined in ':puppet_ssl_cert' setting doesn't exist or is unreadable")
      check_file(ssl_key, "puppet client private key at #{ssl_key} defined in ':puppet_ssl_key' setting doesn't exist or is unreadable")

      true
    end

    def ssl_cert
      Proxy::Puppet::Plugin.settings.puppet_ssl_cert.to_s.empty? ? "/var/lib/puppet/ssl/certs/#{certname}.pem" : Proxy::Puppet::Plugin.settings.puppet_ssl_cert
    end

    def ssl_key
      Proxy::Puppet::Plugin.settings.puppet_ssl_key.to_s.empty? ? "/var/lib/puppet/ssl/private_keys/#{certname}.pem" : Proxy::Puppet::Plugin.settings.puppet_ssl_key
    end

    def check_file(path, message)
      raise ::Proxy::Error::ConfigurationError, message unless File.readable?(path)
    end

    def certname
      Puppet[:certname]
    end
  end
end
