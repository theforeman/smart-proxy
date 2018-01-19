module Proxy::TFTP
  class Plugin < ::Proxy::Plugin
    plugin :tftp, ::Proxy::VERSION

    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    default_settings :tftproot => '/var/lib/tftpboot',
                     :tftp_read_timeout => 60,
                     :tftp_connect_timeout => 10,
                     :tftp_dns_timeout => 10

  end
end