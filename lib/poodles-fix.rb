require 'openssl'
require 'webrick/https'

# Workaround for ruby CVE-2014-3566: creates safe defaults for SSLContext
# also see https://www.ruby-lang.org/en/news/2014/10/27/changing-default-settings-of-ext-openssl/
module OpenSSL
  module SSL
    class SSLContext
      remove_const(:DEFAULT_PARAMS)
      DEFAULT_PARAMS = {
          :ssl_version => "SSLv23",
          :verify_mode => OpenSSL::SSL::VERIFY_PEER,
          :ciphers => %w{
            ECDHE-ECDSA-AES128-GCM-SHA256
            ECDHE-RSA-AES128-GCM-SHA256
            ECDHE-ECDSA-AES256-GCM-SHA384
            ECDHE-RSA-AES256-GCM-SHA384
            DHE-RSA-AES128-GCM-SHA256
            DHE-DSS-AES128-GCM-SHA256
            DHE-RSA-AES256-GCM-SHA384
            DHE-DSS-AES256-GCM-SHA384
            ECDHE-ECDSA-AES128-SHA256
            ECDHE-RSA-AES128-SHA256
            ECDHE-ECDSA-AES128-SHA
            ECDHE-RSA-AES128-SHA
            ECDHE-ECDSA-AES256-SHA384
            ECDHE-RSA-AES256-SHA384
            ECDHE-ECDSA-AES256-SHA
            ECDHE-RSA-AES256-SHA
            DHE-RSA-AES128-SHA256
            DHE-RSA-AES256-SHA256
            DHE-RSA-AES128-SHA
            DHE-RSA-AES256-SHA
            DHE-DSS-AES128-SHA256
            DHE-DSS-AES256-SHA256
            DHE-DSS-AES128-SHA
            DHE-DSS-AES256-SHA
            AES128-GCM-SHA256
            AES256-GCM-SHA384
            AES128-SHA256
            AES256-SHA256
            AES128-SHA
            AES256-SHA
            ECDHE-ECDSA-RC4-SHA
            ECDHE-RSA-RC4-SHA
            RC4-SHA
          }.join(":"),
          :options => lambda do
            opts = OpenSSL::SSL::OP_ALL
            opts &= ~OpenSSL::SSL::OP_DONT_INSERT_EMPTY_FRAGMENTS if defined?(OpenSSL::SSL::OP_DONT_INSERT_EMPTY_FRAGMENTS)
            opts |= OpenSSL::SSL::OP_NO_COMPRESSION if defined?(OpenSSL::SSL::OP_NO_COMPRESSION)
            opts |= OpenSSL::SSL::OP_NO_SSLv2 if defined?(OpenSSL::SSL::OP_NO_SSLv2)
            opts |= OpenSSL::SSL::OP_NO_SSLv3 if defined?(OpenSSL::SSL::OP_NO_SSLv3)
            opts |= OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE if defined?(OpenSSL::SSL::OP_CIPHER_SERVER_PREFERENCE)
            opts
          end.call
      }
    end
  end
end

# POODLES workaround for webrick
module WEBrick
  class GenericServer
    def setup_ssl_context(config) # :nodoc:
      unless config[:SSLCertificate]
        cn = config[:SSLCertName]
        comment = config[:SSLCertComment]
        cert, key = Utils::create_self_signed_cert(1024, cn, comment)
        config[:SSLCertificate] = cert
        config[:SSLPrivateKey] = key
      end
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.set_params
      ctx.key = config[:SSLPrivateKey]
      ctx.cert = config[:SSLCertificate]
      ctx.client_ca = config[:SSLClientCA]
      ctx.extra_chain_cert = config[:SSLExtraChainCert]
      ctx.ca_file = config[:SSLCACertificateFile]
      ctx.ca_path = config[:SSLCACertificatePath]
      ctx.cert_store = config[:SSLCertificateStore]
      ctx.tmp_dh_callback = config[:SSLTmpDhCallback]
      ctx.verify_mode = config[:SSLVerifyClient]
      ctx.verify_depth = config[:SSLVerifyDepth]
      ctx.verify_callback = config[:SSLVerifyCallback]
      ctx.timeout = config[:SSLTimeout]
      ctx.options |= config[:SSLOptions] unless config[:SSLOptions].nil?
      ctx
    end
  end
end
