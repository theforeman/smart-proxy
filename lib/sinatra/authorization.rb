module Sinatra
  module Authorization
    def authorize_with_trusted_hosts
      helpers ::Proxy::Helpers

      before do
        # When :trusted_hosts is given, we check the client against the list
        # HTTPS: test the certificate CN
        # HTTP: test the reverse DNS entry of the remote IP
        trusted_hosts = Proxy::SETTINGS.trusted_hosts
        if trusted_hosts
          logger.debug "verifying remote client #{request.env['REMOTE_ADDR']} against trusted_hosts #{trusted_hosts}"

          if [ 'yes', 'on', 1 ].include? request.env['HTTPS'].to_s
            fqdn = https_cert_cn
          else
            fqdn = remote_fqdn(Proxy::SETTINGS.forward_verify)
          end
          fqdn = fqdn.downcase

          unless Proxy::SETTINGS.trusted_hosts.include?(fqdn)
            log_halt 403, "Untrusted client #{fqdn} attempted to access #{request.path_info}. Check :trusted_hosts: in settings.yml"
          end

        end
      end
    end

    def authorize_with_ssl_client
      helpers ::Proxy::Helpers
      helpers ::Proxy::Log

      before do
        if ['yes', 'on', '1'].include? request.env['HTTPS'].to_s
          if request.env['SSL_CLIENT_CERT'].to_s.empty?
            log_halt 403, "No client SSL certificate supplied"
          end
        else
          logger.debug('require_ssl_client_verification: skipping, non-HTTPS request')
        end
      end

    end
  end
end
