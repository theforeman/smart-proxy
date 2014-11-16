class Proxy::FactsPlugin < ::Proxy::Plugin
  http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

  default_settings :enabled => false
  plugin :facts, ::Proxy::VERSION

  after_activation do
    begin
      require "facter"
    rescue LoadError => e
      ::Proxy::Plugins.disable_plugin(:facts)
      logger.info "#{e} Facter gem was not found, 'facts' module is disabled"
    end
  end
end
