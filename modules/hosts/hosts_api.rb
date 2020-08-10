require 'hosts/proxy_request'

class Proxy::Hosts::Api < ::Sinatra::Base
  helpers ::Proxy::Helpers

  get '/*' do
    Proxy::Hosts::ProxyRequest.new.get(request)
  end

  post '/*' do
    Proxy::Hosts::ProxyRequest.new.post(request)
  end
end
