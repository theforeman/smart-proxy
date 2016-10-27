module Proxy::TFTP
  class Plugin < ::Proxy::Plugin
    plugin :tftp, ::Proxy::VERSION

    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :tftproot => '/var/lib/tftpboot'

    load_classes ::Proxy::TFTP::PluginConfiguration
    load_dependency_injection_wirings ::Proxy::TFTP::PluginConfiguration

    start_services :http_downloads
  end
end
