module Proxy::Httpboot
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    plugin :httpboot, ::Proxy::VERSION

    default_settings :root_dir => '/var/lib/tftpboot'

    expose_setting :http_port
    expose_setting :https_port

    after_activation do
      plugin = ::Proxy::Plugins.instance.find{|p| p[:name] == :httpboot}
      settings[:http_port] = plugin[:http_enabled] ? Proxy::SETTINGS.http_port : nil
      settings[:https_port] = plugin[:https_enabled] ? Proxy::SETTINGS.https_port : nil
    end
  end
end
