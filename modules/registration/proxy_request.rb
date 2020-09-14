require 'proxy/request'

module Proxy::Registration
  class ProxyRequest < ::Proxy::HttpRequest::ForemanRequest
    def global_register(request)
      proxy_req = request_factory.create_get '/register',
                                             request_params(request),
                                             headers(request)

      send_request(proxy_req)
    end

    def host_register(request)
      proxy_req = request_factory.create_post '/register',
                                              request.body.read,
                                              headers(request),
                                              request_params(request)

      send_request(proxy_req)
    end

    private

    def request_params(request)
      params = request.params
      params[:url] = request.env['REQUEST_URI']&.split('/register')&.first
      params
    end

    def headers(request)
      Hash[request.env.select { |k, v| k =~ /^HTTP_/ && k !~ /^HTTP_(VERSION|HOST)$/ }.map { |k, v| [k[5..-1], v] }]
    rescue Exception => e
      logger.warn "Unable to extract request headers: #{e}"
      {}
    end
  end
end
