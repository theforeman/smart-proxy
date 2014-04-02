class Proxy::FactsPlugin < ::Proxy::Plugin
  http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

  default_settings :enabled => true
  plugin :facts, ::Proxy::VERSION
end
