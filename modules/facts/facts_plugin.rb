class Proxy::FactsPlugin < ::Proxy::Plugin
  http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

  default_settings :enabled => false
  plugin :facts, ::Proxy::VERSION

  after_activation do
    begin
      require "facter"
    rescue LoadError => e
      logger.error "Facter gem was not found"
      raise e
    end
  end
end
