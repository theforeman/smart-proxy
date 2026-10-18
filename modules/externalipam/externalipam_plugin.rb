require 'externalipam/phpipam/phpipam_plugin'
require 'externalipam/netbox/netbox_plugin'

module Proxy::Ipam
  class Plugin < ::Proxy::Plugin
    plugin :externalipam, ::Proxy::VERSION
    uses_provider
    default_settings use_provider: nil
    rackup_path File.expand_path('http_config.ru', __dir__)
  end
end
