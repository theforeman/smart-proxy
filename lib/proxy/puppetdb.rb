require 'open-uri'
require 'net/https'
require 'net/http'

module Proxy

    class PuppetDB
      include Proxy::Log
      include Proxy::Util

      def generic_query(endpoint, query=nil, order_query=nil)
         # if we stop using the puppetdb gem we will want to not decode this parameter
         query = URI.encode(query) if not query.nil?
         order_query = URI.encode(order_query) if not order_query.nil?
         puppetdb_request(endpoint, query, order_query)
      end

      private

      def client(uri)
        if @client.nil?
          @client = Net::HTTP.new(uri.host, uri.port)
          if is_secure?
            @client.use_ssl = true
            @client.cert = OpenSSL::X509::Certificate.new(File.read(SETTINGS.ssl_certificate))
            @client.key = OpenSSL::PKey::RSA.new(File.read(SETTINGS.ssl_private_key))
            @client.ca_file = SETTINGS.ssl_ca_file
            @client.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end
        end
        @client
      end

      def puppetdb_request(endpoint, query=nil, order_query=nil)
        if query.nil?
          url = "#{server}/#{apiversion}/#{endpoint}"
        else
          url = "#{server}/#{apiversion}/#{endpoint}?query=#{query}"
        end
        if not order_query.nil?
          url +='&order-by=' + order_query
        end
        logger.debug(url)
        uri = URI.parse(url)
        logger.debug url
        httpclient = client(uri)
        httpclient.get(uri.request_uri).body
      end

      def is_secure?
        SETTINGS.puppetdb_host.start_with?('https')
      end

      def server
        if is_secure?
          if valid_keys?
            SETTINGS.puppetdb_host
          end
        else
          SETTINGS.puppetdb_host
        end
      end

      # gets the apiversion or sets default to 3 if not specified
      def apiversion
        if (1..3).include?(SETTINGS.puppetdb_api_version)
          "v#{SETTINGS.puppetdb_api_version}"
        else
          'v3'
        end
      end

      # checks if the keys exists and caches true or raises error
      def valid_keys?
        if @valid_keys.nil?
          raise "#{SETTINGS.ssl_private_key} does not exist" if ! File.exists?(SETTINGS.ssl_private_key)
          raise "#{SETTINGS.ssl_certificate} does not exist" if ! File.exists?(SETTINGS.ssl_certificate)
          raise "#{SETTINGS.ssl_ca_file} does not exist" if ! File.exists?(SETTINGS.ssl_ca_file)
        end
        @valid_keys ||= true
      end

    end



end
