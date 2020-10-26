require 'proxy/request'

module Proxy::Registration
  class ProxyRequest < ::Proxy::HttpRequest::ForemanRequest
    def global_register(request)
      proxy_req = request_factory.create_get '/register',
                                             request_params(request),
                                             headers(request)

      send_request(proxy_req)
    end

    # we support two way of sending data - either a JSON or url encoded data
    def host_register(request)
      if request.content_type == 'application/x-www-form-urlencoded'
        # the request has a different content type, ForemanRequestFactory sets content type to json, unless
        # specified explicitly
        # also request.params contain the same data that is in request.body, just parsed to hash,
        # in case they are nested (e.g. host hash) we need this causes problem during CGI escaping
        # therefore we only add url, everything else should be in body in this type of request
        proxy_req = request_factory.create_post '/register',
                                                request.body.read,
                                                headers(request).merge("Content-Type" => request.content_type),
                                                { url: register_url(request) }
      else
        # the application/json request body contains the data - JSON as a string, query contains only the URL
        proxy_req = request_factory.create_post '/register',
                                                request.body.read,
                                                headers(request),
                                                request_params(request)
      end

      send_request(proxy_req)
    end

    private

    def request_params(request)
      params = request.params
      params[:url] = register_url(request)
      params
    end

    def register_url(request)
      request.env['REQUEST_URI']&.split('/register')&.first
    end

    def headers(request)
      Hash[request.env.select { |k, v| k =~ /^HTTP_/ && k !~ /^HTTP_(VERSION|HOST)$/ }.map { |k, v| [k[5..-1], v] }]
    rescue Exception => e
      logger.warn "Unable to extract request headers: #{e}"
      {}
    end
  end
end
