module Proxy::PuppetCustomrun
  class Plugin < Proxy::Provider
    plugin :puppet_proxy_customrun, ::Proxy::VERSION

    load_classes ::Proxy::PuppetCustomrun::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetCustomrun::PluginConfiguration

    validate_presence :command, :command_arguments
  end
end
