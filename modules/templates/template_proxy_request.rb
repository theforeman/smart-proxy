require "proxy/util"
require 'proxy/request'
require 'uri'

module Proxy::Templates

  class TemplateProxyRequest < ::Proxy::HttpRequest::ForemanRequest
    include Proxy::Log

    def get_template(kind, env, params)
      url = Proxy::Templates::Plugin.settings.template_url
      proxy_ip = URI.parse(url).host
      opts = params.clone.merge(:url => url)
      opts.delete("kind")
      opts.delete("splat")
      opts.delete("captures")
      proxy_headers = extract_request_headers(env).merge("X-Forwarded-For" => "#{env['REMOTE_ADDR']}, #{proxy_ip}")
      proxy_req = request_factory.create_get("/unattended/#{kind}", opts, proxy_headers)
      logger.debug "Retrieving a template from %s/%s" % [url, proxy_req.path]
      logger.debug "HTTP headers: #{proxy_headers.inspect}"
      res = send_request(proxy_req)

      # You get a 201 from the 'built' URL
      raise "Error retrieving #{kind} for #{opts.inspect} from #{uri.host}: #{res.class}" unless ["200", "201"].include?(res.code)
      Proxy::Log.logger.info "Template: request for #{kind} using #{opts.inspect} at #{uri.host}"
      res.body
    end

    def extract_request_headers(env)
      Hash[env.select{|k,v| k =~ /^HTTP_/ && k !~ /^HTTP_(VERSION|HOST)$/}.map{|k,v| [k[5..-1],v]}]
    rescue Exception => e
      logger.warn "Unable to extract request headers: #{e}"
      {}
    end
  end

end
