require "proxy/util"
require 'proxy/request'
require 'uri'

module Proxy::Hosts
  class ProxyRequest < ::Proxy::HttpRequest::ForemanRequest
    def get(request)
      headers = extract_request_headers(request.env)
      path = "/api#{request.path}"
      proxy_req = request_factory.create_get(path, {}, headers)
      res = send_request(proxy_req)

      res.body
    end

    def post(request)
      headers = extract_request_headers(request.env)
      path = "/api#{request.path}"
      proxy_req = request_factory.create_post(path, request.body.read, headers, {})
      res = send_request(proxy_req)

      res.body
    end

    private

    def extract_request_headers(env)
      Hash[env.select { |k, v| k =~ /^HTTP_/ && k !~ /^HTTP_(VERSION|HOST)$/ }.map { |k, v| [k[5..-1], v] }]
    rescue Exception => e
      logger.warn "Unable to extract request headers: #{e}"
      {}
    end
  end
end
