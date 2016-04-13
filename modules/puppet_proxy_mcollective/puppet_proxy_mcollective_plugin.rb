module Proxy::PuppetMCollective
  class Plugin < Proxy::Provider
    plugin :puppet_proxy_mcollective, ::Proxy::VERSION

    load_classes ::Proxy::PuppetMCollective::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetMCollective::PluginConfiguration
  end
end
