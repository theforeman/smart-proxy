module Proxy::BMC
  class Plugin < Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))

    default_settings :redfish_verify_ssl => true
    validate :redfish_verify_ssl, :boolean => true
    plugin :bmc, ::Proxy::VERSION
  end
end
