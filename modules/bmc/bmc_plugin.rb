module Proxy::BMC
  class Plugin < Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    default_settings :redfish_verify_ssl => true
    validate :redfish_verify_ssl, :boolean => true
    plugin :bmc, ::Proxy::VERSION

    # Various installed providers are exposed as capabilties
    capability 'redfish'
    capability 'shell'
    capability 'ssh'
    capability -> { Proxy::BMC::IPMI.providers_installed }

    # Load IPMI to ensure the capabilities can be determined
    load_classes do
      require 'bmc/ipmi'
    end
  end
end
