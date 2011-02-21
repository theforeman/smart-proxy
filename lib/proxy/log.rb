module Proxy::Log
  @@logger = nil
  def logger
    return @@logger if @@logger

    # If we are running as a library in a rails app then use the provided logger
    if defined?(RAILS_DEFAULT_LOGGER)
      @@logger = RAILS_DEFAULT_LOGGER
    else
      # We must make our own ruby based logger if we are a standalone proxy server
      require 'logger'
      # We keep the last 6 10MB log files
      @@logger = Logger.new(SETTINGS.log_file, 6, 1024*1024*10)
      @@logger.level = SETTINGS.log_level if SETTINGS.log_level
    end
    @@logger
  end
end
