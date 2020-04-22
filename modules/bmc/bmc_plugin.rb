module Proxy::BMC
  class Plugin < Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    default_settings :redfish_verify_ssl => true
    validate :redfish_verify_ssl, :boolean => true
    plugin :bmc, ::Proxy::VERSION
  end
end
