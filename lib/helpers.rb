class SmartProxy < Sinatra::Base

  helpers do
    def log_halt code, message
      content_type :json if request.accept.include?("application/json")
      logger.error message
      halt code, message
    end
  end

end
