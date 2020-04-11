module Proxy::Httpboot
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))

    plugin :httpboot, ::Proxy::VERSION

    load_programmable_settings do |settings|
      settings[:http_port] = ::Proxy::Settings::Plugin.http_enabled?(settings[:enabled]) ? Proxy::SETTINGS.http_port : nil
      settings[:https_port] = ::Proxy::Settings::Plugin.https_enabled?(settings[:enabled]) ? Proxy::SETTINGS.https_port : nil
      settings
    end

    default_settings :root_dir => '/var/lib/tftpboot'

    expose_setting :http_port
    expose_setting :https_port
  end
end
