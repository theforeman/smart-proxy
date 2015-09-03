class Proxy::DhcpPlugin < ::Proxy::Plugin
  http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

  default_settings :dhcp_provider => 'isc', :dhcp_server => '127.0.0.1', :dhcp_omapi_port => '7911'
  plugin :dhcp, ::Proxy::VERSION
end
