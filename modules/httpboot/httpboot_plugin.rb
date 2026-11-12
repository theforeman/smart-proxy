module Proxy::Httpboot
  class Plugin < ::Proxy::Plugin
    rackup_path File.expand_path("http_config.ru", __dir__)

    plugin :httpboot, ::Proxy::VERSION

    load_programmable_settings do |settings|
      unless settings[:request_limit_5m].is_a?(Integer) && settings[:request_limit_5m] >= 0
        raise ArgumentError, 'httpboot request_limit_5m must be a non-negative integer'
      end

      settings[:http_port] = ::Proxy::Settings::Plugin.http_enabled?(settings[:enabled]) ? Proxy::SETTINGS.http_port : nil
      settings[:https_port] = ::Proxy::Settings::Plugin.https_enabled?(settings[:enabled]) ? Proxy::SETTINGS.https_port : nil
      settings
    end

    default_settings :root_dir => '/var/lib/tftpboot', :request_limit_5m => 300

    expose_setting :http_port
    expose_setting :https_port
  end
end
