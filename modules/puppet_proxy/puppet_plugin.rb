module Proxy::Puppet
  class Plugin < Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    plugin :puppet, ::Proxy::VERSION

    uses_provider
    load_programmable_settings ::Proxy::Puppet::ConfigurationLoader
    load_classes ::Proxy::Puppet::ConfigurationLoader
  end
end
