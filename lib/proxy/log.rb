module Proxy::Log
  def logger
    # If we are running as a library in a rails app then use the provided logger
    return RAILS_DEFAULT_LOGGER if defined?(RAILS_DEFAULT_LOGGER)

    # We must make our own ruby based logger if we are a standalone proxy server
    require 'logger'
    # We keep the last 6 10MB log files
    return Logger.new(SETTINGS[:log_file], 6, 1024*1024*10)
  end
end
