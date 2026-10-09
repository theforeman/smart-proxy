class ::Proxy::WolPlugin < ::Proxy::Plugin
  rackup_path File.expand_path("http_config.ru", __dir__)

  plugin :wol, ::Proxy::VERSION
  default_settings :enabled => true

  after_activation do
    logger.debug "Wake-on-LAN plugin initialized"
  end
end
