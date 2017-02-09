require 'net/https'
require 'openssl'

module Proxy::WebhookRealm
  class Provider
    def initialize(config)
      @config = config
    end

    def configure_webhook
      wh = Net::HTTP.new(config[:host], config[:port])
      wh.use_ssl = config[:use_ssl]
      wh.verify_mode = OpenSSL::SSL::VERIFY_NONE unless config[:verify_ssl]
      wh
    end

    def construct_request operation, hostname, params
      req = Net::HTTP::Post.new(config[:path])
      data = JSON.generate(config[:json_keys][:params] => params, config[:json_keys][:operation] => operation, config[:json_keys][:hostname] => hostname) # Sending all params
      req.body = data
      if config[:signing][:enabled]
        req[config[:signing][:header_name]] = "sha1=#{hmac(data)}"
      end
      req["User-Agent"] = "Foreman Smart Proxy"
      req["Accept"] = "application/json"
      req["Content-Type"] = "application/json"
      config[:headers].each { |k,v| req[k] = v }
      req
    end

    def create realm, hostname, params
      params.delete("hostname")
      request "create", hostname, params
    end

    def delete realm, hostname
      request "delete", hostname, {}
    end

    def find hostname
      {}
    end

    private

    def config
      @config
    end

    def webhook
      @webhook ||= configure_webhook
    end

    def hmac data
      OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new(config[:signing][:algorithm]),
        config[:signing][:secret],
        data
      )
    end

    def request operation, hostname, params
      webhook.request(construct_request(operation, hostname, params)).body
    end
  end
end
