require 'registration/proxy_request'

class Proxy::Registration::Api < ::Sinatra::Base
  get '/' do
    response = Proxy::Registration::ProxyRequest.new.global_register(request)
    handle_response(response)
  rescue StandardError => e
    logger.exception "Error when rendering Global Registration Template", e
    render_error(default_error_msg)
  end

  post '/' do
    response = Proxy::Registration::ProxyRequest.new.host_register(request)
    handle_response(response)
  rescue StandardError => e
    logger.exception "Error when rendering Host Registration Template", e
    render_error(default_error_msg)
  end

  private

  def handle_response(response)
    if response.code.start_with? '2'
      response.body
    else
      # Return error message only if it is not HTML.
      message = response["content-type"].include?('text/plain') ? response.body : default_error_msg
      render_error(message, code: response.code)
    end
  end

  def render_error(message, code: 500)
    status code
    message
  end

  def default_error_msg
    "echo \"Internal Server Error\"\nexit 1\n"
  end
end
