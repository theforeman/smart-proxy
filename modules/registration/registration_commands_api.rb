require 'registration/proxy_request'

class Proxy::Registration::CommandsApi < ::Sinatra::Base
  post '/' do
    content_type :json
    response = Proxy::Registration::ProxyRequest.new.registration_command(request)
    handle_response(response)
  rescue StandardError => e
    logger.exception "Error when proxying registration command", e
    render_error('Failed to generate registration command')
  end

  private

  def handle_response(response)
    if response.code.start_with? '2'
      response.body
    else
      render_error(response.body, code: response.code)
    end
  end

  def render_error(message, code: 500)
    status code
    message
  end
end
