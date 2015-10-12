module Proxy::Puppet
  class Plugin < Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :puppet_provider => 'puppetrun', :puppet_conf => '/etc/puppet/puppet.conf', :use_cache => true,
                     :salt_puppetrun_cmd => 'puppet.run', :puppet_ssl_ca => '/var/lib/puppet/ssl/certs/ca.pem'

    plugin :puppet, ::Proxy::VERSION

    validate_readable :puppet_conf

    after_activation do
      require 'puppet_proxy/initializer'
      require 'puppet_proxy/ssl_configuration_validator'

      ::Proxy::Puppet::Initializer.new.reset_puppet
      ::Proxy::Puppet::SslConfigurationValidator.new.validate_ssl_paths!

      require 'puppet_proxy/dependency_injection/container'
      require 'puppet_proxy/dependency_injection/dependencies'
    end
  end
end
