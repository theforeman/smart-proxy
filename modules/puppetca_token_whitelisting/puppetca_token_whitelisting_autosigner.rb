require 'jwt'
require 'openssl'

module ::Proxy::PuppetCa::TokenWhitelisting
  class Autosigner
    include ::Proxy::Log
    include ::Proxy::Util

    JWT_ALGORITHM = 'RS512'
    RSA_BITSIZE = '2048'

    def tokens_file
      Proxy::PuppetCa::TokenWhitelisting::Plugin.settings.tokens_file
    end

    def sign_all
      Proxy::PuppetCa::TokenWhitelisting::Plugin.settings.sign_all
    end

    def smartproxy_cert
      @certificate ||= OpenSSL::PKey::RSA.new File.read cert_file
    end

    def storage
      Proxy::PuppetCa::TokenWhitelisting::TokenStorage.new tokens_file
    end

    def token_ttl
      Proxy::PuppetCa::TokenWhitelisting::Plugin.settings.token_ttl
    end

    def cert_file
      return Proxy::SETTINGS.ssl_private_key.to_s if Proxy::PuppetCa::TokenWhitelisting::Plugin.settings.certificate.nil?

      file = Proxy::PuppetCa::TokenWhitelisting::Plugin.settings.certificate
      unless File.exist?(file)
        File.write file, OpenSSL::PKey::RSA.generate(RSA_BITSIZE)
        File.chmod 0600, file
      end
      file
    end

    # Invalidate a token based on the certname
    def disable certname
      storage.remove_if do |token|
        begin
          decoded = JWT.decode(token, smartproxy_cert.public_key, true, algorithm: JWT_ALGORITHM)
          decoded.first['certname'] == certname
        rescue JWT::ExpiredSignature
          true
        end
      end
    end

    # Create a new token for a certname
    def autosign certname, ttl
      ttl = ttl.to_i > 0 ? ttl.to_i : token_ttl
      payload = { certname: certname, exp: Time.now.to_i + ttl * 60 }
      token = JWT.encode payload, smartproxy_cert, JWT_ALGORITHM
      storage.add token
      { generated_token: token }.to_json
    end

    # List the hosts that are currently valid
    def autosign_list
      storage.read.collect do |token|
        begin
          decoded = JWT.decode(token, smartproxy_cert.public_key, true, algorithm: JWT_ALGORITHM)
          decoded.first['certname']
        rescue JWT::ExpiredSignature
          nil
        end
      end.compact
    end

    # Check whether a csr is valid and should be signed
    # by checking its token if it exists
    def validate_csr csr
      if csr.nil?
        logger.warn "Request did not include a CSR."
        return false
      end
      if sign_all
        logger.warn "Signing CSR without token verification."
        return true
      end
      begin
        req = Proxy::PuppetCa::TokenWhitelisting::CSR.new csr
        token = req.challenge_password
      rescue
        logger.warn "Invalid CSR"
        return false
      end
      if token.nil?
        logger.warn "CSR did not include a token."
        return false
      end
      validate_token token
    end

    def validate_token token
      # token didnt expire?
      begin
        JWT.decode(token, smartproxy_cert.public_key, true, algorithm: JWT_ALGORITHM)
      rescue JWT::ExpiredSignature
        logger.warn "Token already expired."
        return false
      rescue JWT::DecodeError
        logger.warn "Failed to decode token."
        return false
      end
      # token in our list?
      unless storage.read.include? token
        logger.warn "Certname not valid."
        return false
      end
      storage.remove token
      return true
    end
  end
end
