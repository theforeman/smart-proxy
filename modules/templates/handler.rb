require "proxy/util"
require 'proxy/request'
require 'uri'

module Proxy::Templates

  class Handler < ::Proxy::HttpRequest::ForemanRequest
    extend Proxy::Log

    def get_template(kind, params, static = false)
      opts = {
        :url => Proxy::Templates::Plugin.settings.template_url
      }
      opts[:mac]    = params[:mac] if params.has_key?('mac')
      opts[:token]  = params[:token] if params.has_key?('token')
      opts[:static] = static if static
      request = request_factory.create_get("/unattended/#{kind}", opts)
      res = send_request(request)

      # You get a 201 from the 'built' URL
      raise "Error retrieving #{kind} for #{opts.to_json} from #{uri.host}: #{res.class}" unless ["200", "201"].include?(res.code)
      Proxy::Log.logger.info "Template: request for #{kind} using #{opts.to_json} at #{uri.host}"
      res.body
    end

    def self.get_template kind, params, static = false
      @handler ||= Handler.new
      @handler.get_template(kind, params, static)
    end
  end

end
