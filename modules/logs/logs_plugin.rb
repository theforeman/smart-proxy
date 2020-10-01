class ::Proxy::LogsPlugin < ::Proxy::Plugin
  rackup_path File.expand_path("http_config.ru", __dir__)

  plugin :logs, ::Proxy::VERSION
  default_settings :enabled => true

  after_activation do
    buffer = Proxy::LogBuffer::Buffer.instance
    logger.debug "Log buffer API initialized, available capacity: #{buffer}"
  end
end
