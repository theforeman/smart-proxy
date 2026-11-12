require 'externalipam/phpipam/phpipam_plugin_configuration'

module Proxy::Phpipam
  class Plugin < ::Proxy::Provider
    plugin :externalipam_phpipam, ::Proxy::VERSION
    requires :externalipam, ::Proxy::VERSION
    validate :url, url: true
    validate_presence :user, :password
    load_classes ::Proxy::Phpipam::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::Phpipam::PluginConfiguration
  end
end
