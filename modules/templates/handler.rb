require "proxy/util"
require 'proxy/request'
require 'uri'

module Proxy::Templates

  class Handler < ::Proxy::HttpRequest::ForemanRequest
    include Proxy::Log

    def get_template(kind, token, static = false)
      opts = { :token => token,
               :url   => Proxy::Templates::Plugin.settings.template_url
      }
      opts[:static] = static if static
      request = request_factory.create_get("/unattended/#{kind}", opts)
      logger.debug "retrieving a template from %s/%s" % [Proxy::Templates::Plugin.settings.template_url, request.path]
      res = send_request(request)

      # You get a 201 from the 'built' URL
      raise "Error retrieving #{kind} for #{token} from #{uri.host}: #{res.class}" unless ["200", "201"].include?(res.code)
      res.body
    end

    def self.get_template kind, token, static = false
      @handler ||= Handler.new
      @handler.get_template(kind,token, static)
    end
  end

end
