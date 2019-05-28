require 'templates/proxy_request'

module Proxy::Templates
  class TemplateProxyRequest < ProxyRequest
    def get(kind, env, params)
      super(['unattended', kind].flatten, env, params)
    end

    def post(kind, env, params, body)
      super(['unattended', kind].flatten, env, params, body)
    end
  end
end
