require "proxy/util"
require 'proxy/request'
require 'uri'

module Proxy::Templates

  class TemplateProxyRequest < ::Proxy::HttpRequest::ForemanRequest
    include Proxy::Log

    def call_template(method, kind, env, params, body = '')
      template_url = Proxy::Templates::Plugin.settings.template_url
      proxy_ip = URI.parse(template_url).host
      opts = params.clone.merge(:url => template_url)
      opts.delete("kind")
      opts.delete("template")
      opts.delete("hostgroup")
      opts.delete("splat")
      opts.delete("captures")
      # in hostgroup provisioning there are spaces
      kind = kind.split('/').map{|x| CGI.escape(x)}.join('/')
      logger.debug "Template: request for #{kind} using #{opts.inspect} at #{uri.host}"
      proxy_headers = extract_request_headers(env)
      proxy_headers["X-Forwarded-For"] = "#{env['REMOTE_ADDR']}, #{proxy_ip}"
      proxy_headers["Content-Type"] = params["Content-Type"] if params["Content-Type"]
      if method == :get
        proxy_req = request_factory.create_get("/unattended/#{kind}", opts, proxy_headers)
      elsif method == :post
        proxy_req = request_factory.create_post("/unattended/#{kind}", body, proxy_headers, opts)
      else
        raise "Unknown method: #{method}"
      end
      logger.debug "Retrieving a template from %s%s" % [uri, proxy_req.path]
      logger.debug "HTTP headers: #{proxy_headers.inspect}"
      res = send_request(proxy_req)
      # You get a 201 from the 'built' URL
      raise "Error retrieving #{kind} for #{opts.inspect} from #{uri.host}: #{res.class}" unless ["200", "201"].include?(res.code)
      res.body
    end

    def get(kind, env, params)
      call_template(:get, kind, env, params)
    end

    def post(kind, env, params, body)
      call_template(:post, kind, env, params, body)
    end

    def extract_request_headers(env)
      Hash[env.select{|k,v| k =~ /^HTTP_/ && k !~ /^HTTP_(VERSION|HOST)$/}.map{|k,v| [k[5..-1],v]}]
    rescue Exception => e
      logger.warn "Unable to extract request headers: #{e}"
      {}
    end
  end

end
