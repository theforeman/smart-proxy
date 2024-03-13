module Proxy::TFTP
  class Plugin < ::Proxy::Plugin
    plugin :tftp, ::Proxy::VERSION

    capability -> { settings[:bootloader_universe] ? :target_os_bootloader_support : nil }

    rackup_path File.expand_path("http_config.ru", __dir__)

    default_settings :tftproot => '/var/lib/tftpboot',
                     :tftp_connect_timeout => 10,
                     :verify_server_cert => true
    validate :verify_server_cert, boolean: true

    expose_setting :tftp_servername
  end
end
