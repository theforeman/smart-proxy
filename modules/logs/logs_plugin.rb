class ::Proxy::LogsPlugin < ::Proxy::Plugin
  http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
  https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

  plugin :logs, ::Proxy::VERSION
  default_settings :enabled => true

  after_activation do
    buffer = Proxy::LogBuffer::Buffer.instance
      logger.debug "Log buffer API initialized, available capacity: #{buffer}"
  end
end
