require "proxy/util"
require 'proxy/request'
require 'uri'

module Proxy::Templates

  class Handler < ::Proxy::HttpRequest::ForemanRequest
    extend Proxy::Log

    def get_template(kind, token)
      request = request_factory.create_get("/unattended/#{kind}", :token=> token)
      res = send_request(request)

      # You get a 201 from the 'built' URL
      raise "Error retrieving #{kind} for #{token} from #{uri.host}: #{res.class}" unless ["200", "201"].include?(res.code)
      Proxy::Log.logger.info "Template: request for #{kind} using #{token} at #{uri.host}"
      res.body
    end

    def self.get_template kind, token
      @handler ||= Handler.new
      @handler.get_template(kind,token)
    end
  end

end
