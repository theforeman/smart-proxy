module Proxy::PuppetSsh
  class Plugin < Proxy::Provider
    plugin :puppet_proxy_ssh, ::Proxy::VERSION

    default_settings :command => "puppet agent --onetime --no-usecacheonfailure", :use_sudo => false,
                     :wait => false

    load_classes ::Proxy::PuppetSsh::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::PuppetSsh::PluginConfiguration
  end
end
