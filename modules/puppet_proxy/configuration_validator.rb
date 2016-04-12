require 'uri'

module Proxy::Puppet
  class ConfigurationValidator
    include Proxy::Puppet::RuntimeConfiguration
    attr_reader :settings

    def initialize(settings)
      @settings = settings
    end

    def validate!
      validate_puppet_url!(settings.puppet_url)
      validate_puppet_conf!(settings.puppet_conf)
      validate_ssl_paths!(settings.puppet_ssl_ca, settings.puppet_ssl_cert, settings.puppet_ssl_key)
    end

    def validate_puppet_url!(puppet_url)
      return true if environments_retriever == :config_file
      raise ::Proxy::Error::ConfigurationError, "Setting 'puppet_url' is expected to contain a url for puppet server" if puppet_url.to_s.empty?
      URI.parse(puppet_url)
    rescue URI::InvalidURIError
      raise ::Proxy::Error::ConfigurationError.new("Setting 'puppet_url' expected to contain a url for puppet server contains an invalid url")
    end

    def validate_puppet_conf!(puppet_conf)
      return true if classes_retriever == :api_v3
      check_file(puppet_conf.to_s, "Puppet configuration file '#{puppet_conf}' defined in ':puppet_conf' setting doesn't exist or is unreadable")
      true
    end

    def validate_ssl_paths!(ca_cert, ssl_cert, ssl_key)
      return true if environments_retriever == :config_file

      check_file(ca_cert, "puppet CA certificate at '#{ca_cert}' defined in ':puppet_ssl_ca' setting doesn't exist or is unreadable")
      check_file(ssl_cert, "puppet client certificate at #{ssl_cert} defined in ':puppet_ssl_cert' setting doesn't exist or is unreadable")
      check_file(ssl_key, "puppet client private key at #{ssl_key} defined in ':puppet_ssl_key' setting doesn't exist or is unreadable")

      true
    end

    def check_file(path, message)
      raise ::Proxy::Error::ConfigurationError, message unless File.readable?(path)
    end
  end
end
