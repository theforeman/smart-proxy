module Proxy::PuppetSalt
  class Plugin < Proxy::Provider
    plugin :puppet_proxy_salt, ::Proxy::VERSION

    default_settings :command => "puppet.run"

    load_classes ::Proxy::PuppetSalt::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetSalt::PluginConfiguration
  end
end
