require "proxy/util"
require 'uri'

module Proxy::Template

  class Handler
    extend Proxy::Log

    # Gets a template from Foreman
    def self.get_template kind, token
      # Parse the Foreman URI for a connection
      uri              = URI.parse("#{SETTINGS.foreman_url}/unattended/#{kind}?token=#{token}")
      req              = Net::HTTP::Get.new(uri.request_uri)
      http             = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl     = uri.scheme == 'https'
      # TODO: handle CA properly; for now we'll accept self-signed certs
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?
      res              = http.start { |http| http.request(req) }

      # You get a 201 from the 'built' URL
      raise "Error retrieving #{kind} for #{token} from #{uri.host}: #{res.class}" unless ["200", "201"].include?(res.code)
      logger.info "Template: request for #{kind} using #{token} at #{uri.host}"
      res.body
    end
  end

end
