module Proxy::PuppetRun
  class Plugin < Proxy::Provider
    plugin :puppet_proxy_puppetrun, ::Proxy::VERSION
    load_classes ::Proxy::PuppetRun::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetRun::PluginConfiguration
  end
end
