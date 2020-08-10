require 'templates/proxy_request'

class Proxy::TemplatesRegisterApi < Sinatra::Base
  helpers ::Proxy::Helpers

  get "/" do
    log_halt(500, "Failed to retrieve Global registration template.") do
      Proxy::Templates::ProxyRequest.new.get(['register'], request.env, params)
    end
  end
end
