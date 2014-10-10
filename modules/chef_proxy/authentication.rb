module Proxy::Chef
  class Authentication
    require 'chef'
    require 'digest/sha2'
    require 'base64'
    require 'openssl'

    def verify_signature_request(client_name,signature,body)
      #We need to retrieve node public key
      #to verify signature
      chefurl = Proxy::Chef::Plugin.settings.chef_server_url
      chef_smartproxy_clientname = Proxy::Chef::Plugin.settings.chef_smartproxy_clientname
      key = Proxy::Chef::Plugin.settings.chef_smartproxy_privatekey
      rest = ::Chef::REST.new(chefurl,chef_smartproxy_clientname,key)
      begin
        public_key = OpenSSL::PKey::RSA.new(rest.get_rest("/clients/#{client_name}").public_key)
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError,
             Errno::ECONNREFUSED, OpenSSL::SSL::SSLError => e
        raise Proxy::Error::Unauthorized, "Failed to authenticate node : "+e.message
      end

      #signature is base64 encoded
      decoded_signature = Base64.decode64(signature)
      hash_body = Digest::SHA256.hexdigest(body)
      public_key.verify(OpenSSL::Digest::SHA256.new,decoded_signature,hash_body)
    end

    def authenticated(request, &block)
      content     = request.env["rack.input"].read

      auth = true
      if Proxy::Chef::Plugin.settings.chef_authenticate_nodes
        client_name = request.env['HTTP_X_FOREMAN_CLIENT']
        signature   = request.env['HTTP_X_FOREMAN_SIGNATURE']

        raise Proxy::Error::Unauthorized, "Failed to authenticate node #{client_name}. Missing some headers" if client_name.nil? || signature.nil?
        auth = verify_signature_request(client_name,signature,content)
      end

      if auth
        raise Proxy::Error::BadRequest, "Body is empty for node #{client_name}" if content.nil?
        block.call(content)
      else
        raise Proxy::Error::Unauthorized, "Failed to authenticate node #{client_name}"
      end
    end
  end
end
