class Proxy::DhcpPlugin < ::Proxy::Plugin
  http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

  uses_provider
  default_settings :use_provider => 'dhcp_isc', :server => '127.0.0.1', :subnets => []
  expose_setting :use_provider
  plugin :dhcp, ::Proxy::VERSION

  load_classes ::Proxy::DHCP::ConfigurationLoader
end
