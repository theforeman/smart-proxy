require 'templates/userdata_proxy_request'

class Proxy::TemplatesUserdataApi < Sinatra::Base
  helpers ::Proxy::Helpers

  get "/:kind" do |kind|
    log_halt(500, "Failed to retrieve #{kind} userdata template for #{params.inspect}: ") do
      Proxy::Templates::UserdataProxyRequest.new.get(kind, request.env, params)
    end
  end
end
