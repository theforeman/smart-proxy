require "proxy/util"
require 'proxy/request'
require 'uri'

module Proxy::Templates

  class Handler < ::Proxy::HttpRequest::ForemanRequest
    include Proxy::Log

    def get_template(kind, params)
      opts = {
        :url => Proxy::Templates::Plugin.settings.template_url
      }
      # mac parameter will be only searched when foreman_bootdisk plugin is enabled on the foreman side
      opts[:mac]    = params[:mac] if params.has_key?(:mac)
      opts[:token]  = params[:token] if params.has_key?(:token)
      opts[:static] = params[:static] if params.has_key?(:static)
      request = request_factory.create_get("/unattended/#{kind}", opts)
      logger.debug "retrieving a template from %s/%s" % [Proxy::Templates::Plugin.settings.template_url, request.path]
      res = send_request(request)

      # You get a 201 from the 'built' URL
      raise "Error retrieving #{kind} for #{opts.inspect} from #{uri.host}: #{res.class}" unless ["200", "201"].include?(res.code)
      Proxy::Log.logger.info "Template: request for #{kind} using #{opts.inspect} at #{uri.host}"
      res.body
    end

    def self.get_template(kind, params)
      @handler ||= Handler.new
      @handler.get_template(kind, params)
    end
  end

end
