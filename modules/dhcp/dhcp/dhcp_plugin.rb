class Proxy::DhcpPlugin < ::Proxy::Plugin
  http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

  default_settings :dhcp_provider => 'isc'
  plugin :dhcp, ::Proxy::VERSION
end