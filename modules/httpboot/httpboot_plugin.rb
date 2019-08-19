module Proxy::Httpboot
  class Plugin < ::Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    plugin :httpboot, ::Proxy::VERSION
    load_programmable_settings ::Proxy::Httpboot::PluginConfiguration

    default_settings :root_dir => '/var/lib/tftpboot'

    expose_setting :http_port
    expose_setting :https_port
  end
end
