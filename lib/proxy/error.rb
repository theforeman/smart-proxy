module Proxy::Error
  class HttpError < StandardError
    attr_reader :status_code, :response_body
    def initialize(status_code, response_body, msg = nil)
      @status_code = status_code
      @response_body = response_body
      super(msg)
    end
  end

  class ConfigurationError < StandardError; end
end
