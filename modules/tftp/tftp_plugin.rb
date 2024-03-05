module Proxy::TFTP
  class Plugin < ::Proxy::Plugin
    plugin :tftp, ::Proxy::VERSION

    rackup_path File.expand_path("http_config.ru", __dir__)

    load_programmable_settings do |settings|
      settings[:http_port] = ::Proxy::Settings::Plugin.http_enabled?(settings[:enabled]) ? Proxy::SETTINGS.http_port : nil
      settings
    end

    default_settings :tftproot => '/var/lib/tftpboot',
                     :tftp_connect_timeout => 10,
                     :verify_server_cert => true,
                     :enable_system_image => true,
                     :system_image_root => '/var/lib/foreman-proxy/tftp/system_images'
    validate :verify_server_cert, boolean: true

    # Expose automatic iso handling capability
    capability -> { settings[:enable_system_image] ? 'system_image' : nil }

    expose_setting :tftp_servername
    expose_setting :http_port
  end
end
