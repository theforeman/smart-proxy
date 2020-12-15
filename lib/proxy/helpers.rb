require 'openssl'
require 'proxy/logging_resolv'

module Proxy::Helpers
  include Proxy::Log

  # Accepts a html error code and a message, which is then returned to the caller after adding to the proxy log
  # OR  a block which is executed and its errors handled in a similar way.
  # If no code is supplied when the block is declared then the html error used is 400.
  def log_halt(code = nil, exception_or_msg = nil, custom_msg = nil)
    message = exception_or_msg.to_s
    message = "#{custom_msg}: #{message}" if custom_msg
    exception = exception_or_msg.is_a?(Exception) ? exception_or_msg : Exception.new(exception_or_msg)
    # just in case exception is passed in the 3rd parameter let's not loose the valuable info
    exception = custom_msg.is_a?(Exception) ? custom_msg : exception
    begin
      if block_given?
        return yield
      end
    rescue => e
      exception = e
      message += e.message
      code ||= 400
    end
    content_type :json if request.accept?("application/json")
    logger.error message, exception
    logger.exception(message, exception) if exception.is_a?(Exception)
    halt code, message
  end

  # parses the body as json and returns a hash of the body
  # returns empty hash if there is a json parse error, the body is empty or is not a hash
  # request.env["CONTENT_TYPE"] must contain application/json in order for the json to be parsed
  def parse_json_body(request)
    json_data = {}
    # if the user has explicitly set the content_type then there must be something worth decoding
    # we use a regex because it might contain something else like: application/json;charset=utf-8
    # by default the content type will probably be set to "application/x-www-form-urlencoded" unless the
    # user changed it.  If the user doesn't specify the content type we just ignore the body since a form
    # will be parsed into the request.params object for us by sinatra
    if request.media_type == 'application/json'
      begin
        body_parameters = request.body.read
        json_data = JSON.parse(body_parameters)
      rescue => e
        log_halt 415, "Invalid JSON content in body of request: \n#{e.message}"
      end

      log_halt 415, "Invalid JSON content in body of request: data must be a hash, not #{json_data.class.name}" unless json_data.is_a?(Hash)
    end
    json_data
  end

  def dns_resolv(*args)
    resolv = Resolv::DNS.new(*args)
    resolv.timeouts = Proxy::SETTINGS.dns_resolv_timeouts
    ::Proxy::LoggingResolv.new(resolv)
  end

  def resolv(*args)
    ::Proxy::LoggingResolv.new(Resolv.new(*args))
  end
end
