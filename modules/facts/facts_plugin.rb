class Proxy::FactsPlugin < ::Proxy::Plugin
  http_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path(__dir__))

  default_settings :enabled => false
  plugin :facts, ::Proxy::VERSION

  load_classes do
    require "facter"
  rescue LoadError => e
    logger.error "Facter gem was not found"
    raise e
  end
end
