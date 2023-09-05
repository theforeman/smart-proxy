module Proxy::Puppet
  class Plugin < Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    plugin :puppet, ::Proxy::VERSION

    load_classes ::Proxy::Puppet::ConfigurationLoader
    load_dependency_injection_wirings ::Proxy::Puppet::ConfigurationLoader

    default_settings :puppet_ssl_ca => '/etc/puppetlabs/puppet/ssl/certs/ca.pem', :api_timeout => 30
    validate :puppet_url, :url => true
    expose_setting :puppet_url
    validate_readable :puppet_ssl_ca, :puppet_ssl_cert, :puppet_ssl_key
  end
end
