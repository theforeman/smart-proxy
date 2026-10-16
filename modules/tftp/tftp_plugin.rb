module Proxy::TFTP
  class Plugin < ::Proxy::Plugin
    plugin :tftp, ::Proxy::VERSION

    capability :bootloader_universe
    capability :bootloader_archive_tgz
    capability :bootloader_archive_iso
    capability :bootloader_universe_boot_files

    rackup_path File.expand_path("http_config.ru", __dir__)

    default_settings :tftproot => '/var/lib/tftpboot',
                     :tftp_connect_timeout => 10,
                     :tftp_download_max_time => 3600,
                     :verify_server_cert => true,
                     :tftp_http_download_preflight => true
    validate :verify_server_cert, boolean: true
    validate :tftp_http_download_preflight, boolean: true

    expose_setting :tftp_servername
  end
end
