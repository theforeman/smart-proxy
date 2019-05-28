require 'templates/proxy_request'

module Proxy::Templates
  class UserdataProxyRequest < ProxyRequest
    def get(kind, env, params)
      super(['userdata', kind].flatten, env, params)
    end

    def post(kind, env, params, body)
      super(['userdata', kind].flatten, env, params, body)
    end
  end
end
