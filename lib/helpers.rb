class SmartProxy < Sinatra::Base

  helpers do
    def log_halt code, message
      logger.error message
      halt code, message
    end
  end

end
