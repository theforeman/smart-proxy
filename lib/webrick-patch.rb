require 'webrick/https'

CIPHERS = ['ECDHE-RSA-AES128-GCM-SHA256','ECDHE-RSA-AES256-GCM-SHA384',
           'ECDHE-RSA-AES128-CBC-SHA','ECDHE-RSA-AES256-CBC-SHA',
           'AES128-GCM-SHA256','AES256-GCM-SHA384','AES128-SHA256',
           'AES256-SHA256','AES128-SHA','AES256-SHA']

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
      ctx.ciphers = (CIPHERS - Proxy::SETTINGS.ssl_disabled_ciphers).join(':')
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
