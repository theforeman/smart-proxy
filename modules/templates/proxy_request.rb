require "proxy/util"
require 'proxy/request'
require 'uri'

module Proxy::Templates
  class ProxyRequest < ::Proxy::HttpRequest::ForemanRequest
    include Proxy::Log

    BLACKLIST_PARAMETERS = ['path', 'template', 'kind', 'hostgroup', 'splat', 'captures']

    def get(path, env, params)
      call_template(:get, path, env, params)
    end

    def post(path, env, params, body)
      call_template(:post, path, env, params, body)
    end

    def extract_request_headers(env)
      Hash[env.select { |k, v| k =~ /^HTTP_/ && k !~ /^HTTP_(VERSION|HOST)$/ }.map { |k, v| [k[5..-1], v] }]
    rescue Exception => e
      logger.warn "Unable to extract request headers: #{e}"
      {}
    end

    private

    def call_template(method, path, env, params, body = '')
      template_url = Proxy::Templates::Plugin.settings.template_url
      opts = params.clone.merge(:url => template_url)
      BLACKLIST_PARAMETERS.each do |blacklisted_parameter|
        opts.delete(blacklisted_parameter)
      end
      # in hostgroup provisioning there are spaces
      path = path.map { |x| CGI.escape(x) }.join('/')
      logger.debug "Template: request for #{path} using #{opts.inspect} at #{uri.host}"
      proxy_headers = extract_request_headers(env)
      proxy_headers["X-Forwarded-For"] = env['REMOTE_ADDR']
      proxy_headers["Content-Type"] = params["Content-Type"] if params["Content-Type"]
      if method == :get
        proxy_req = request_factory.create_get(path, opts, proxy_headers)
      elsif method == :post
        proxy_req = request_factory.create_post(path, body, proxy_headers, opts)
      else
        raise "Unknown method: #{method}"
      end
      logger.debug "Retrieving a template from %s%s" % [uri, proxy_req.path]
      logger.debug "HTTP headers: #{proxy_headers.inspect}"
      res = send_request(proxy_req)
      # You get a 201 from the 'built' URL
      raise "Error retrieving #{path} for #{opts.inspect} from #{uri.host}: #{res.class}" unless ["200", "201"].include?(res.code)
      res.body
    end
  end
end
