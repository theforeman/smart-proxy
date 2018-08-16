module Proxy::Httpboot
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    plugin :httpboot, ::Proxy::VERSION
    requires :tftp, ::Proxy::VERSION

    default_settings :root_dir => '/var/lib/tftpboot'
  end
end
