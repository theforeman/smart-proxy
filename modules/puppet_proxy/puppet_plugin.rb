module Proxy::Puppet
  class Plugin < Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :puppet_provider => 'puppetrun', :puppet_conf => '/etc/puppet/puppet.conf', :use_cache => true,
                     :salt_puppetrun_cmd => 'puppet.run', :puppet_ssl_ca => '/var/lib/puppet/ssl/certs/ca.pem'

    plugin :puppet, ::Proxy::VERSION

    validate_presence :puppet_version

    after_activation do
      require 'puppet_proxy/puppet_config' if settings.puppet_version.to_s < '4.0'
      require 'puppet_proxy/runtime_configuration'

      require 'puppet_proxy/configuration_validator'
      ::Proxy::Puppet::ConfigurationValidator.new(settings).validate!

      require 'puppet' if settings.puppet_version.to_s < '4.0'
      require 'puppet_proxy/initializer' if settings.puppet_version.to_s < '4.0'

      require 'puppet_proxy/environments_retriever_base'
      require 'puppet_proxy/class_scanner_base'
      require 'puppet_proxy/environment'
      require 'puppet_proxy/puppet_class'
      require 'puppet_proxy/dependency_injection/container'
      require 'puppet_proxy/dependency_injection/dependencies'
    end
  end
end
