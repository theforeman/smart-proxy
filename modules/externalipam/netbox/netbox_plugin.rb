require 'externalipam/netbox/netbox_plugin_configuration'

module Proxy::Netbox
  class Plugin < ::Proxy::Provider
    plugin :externalipam_netbox, ::Proxy::VERSION
    requires :externalipam, ::Proxy::VERSION
    validate :url, url: true
    validate_presence :token
    load_classes ::Proxy::Netbox::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::Netbox::PluginConfiguration
  end
end
