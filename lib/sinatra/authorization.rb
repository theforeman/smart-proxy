module Sinatra
  module Authorization
    # Authorization helper for more granular authorization (such as per-route authorization)
    #
    # Usage:
    #
    #  class MyPlugin < ::Sinatra::Base
    #    include Sinatra::Authorization::Helpers
    #
    #    get '/my_public_api' do
    #      # ...
    #    end
    #
    #    get 'my_secret_api' do
    #      # Authorize using the common set of authorization methods
    #      do_authorize_any
    #      # ...
    #    end
    #  end
    #
    module Helpers
      def self.included(base)
        base.helpers ::Proxy::Helpers
        base.helpers ::Proxy::Log
      end

      def do_authorize_with_trusted_hosts
        # When :trusted_hosts is given, we check the client against the list
        # HTTPS: test the certificate CN
        # HTTP: test the reverse DNS entry of the remote IP
        trusted_hosts = Proxy::SETTINGS.trusted_hosts
        if trusted_hosts
          fqdn = (https?(request) ? https_cert_cn(request) : remote_fqdn(Proxy::SETTINGS.forward_verify)).downcase

          logger.debug "verifying remote client #{fqdn} against trusted_hosts #{trusted_hosts}"

          unless trusted_hosts.include?(fqdn)
            log_halt 403, "Untrusted client #{fqdn} attempted to access #{request.path_info}. Check :trusted_hosts: in settings.yml"
          end
        end
      end

      def do_authorize_with_ssl_client
        if https?(request)
          if https_client_cert_raw(request).empty?
            log_halt 403, "No client SSL certificate supplied"
          end
        else
          logger.debug('require_ssl_client_verification: skipping, non-HTTPS request')
        end
      end

      # Common set of authorization methods used in foreman-proxy
      def do_authorize_any
        do_authorize_with_trusted_hosts
        do_authorize_with_ssl_client
      end

      private

      def https?(request)
        ['yes', 'on', 1].include?(request.env['HTTPS'].to_s)
      end

      def https_client_cert_raw(request)
        request.env['SSL_CLIENT_CERT'].to_s
      end

      # read the HTTPS client certificate from the environment and extract its CN
      def https_cert_cn(request)
        log_halt 403, 'No HTTPS environment' unless https?(request)

        certificate_raw = https_client_cert_raw(request)
        certificate = parse_openssl_cert(certificate_raw)
        log_halt 403, 'could not read client cert from environment' unless certificate

        cn = get_cn_from_certificate(certificate)
        log_halt 403, 'could not read CN from the client certificate' unless certificate

        cn
      rescue OpenSSL::X509::CertificateError => e
        log_halt 403, "could not parse the client certificate\n\n#{e.message}"
      end

      # reverse lookup an IP address while verifying it via forward resolv
      def remote_fqdn(forward_verify = true)
        ip = request.env['REMOTE_ADDR']
        log_halt 403, 'could not get remote address from environment' if ip.empty?

        begin
          dns = resolv
          fqdn = dns.getname(ip)
        rescue Resolv::ResolvError => e
          log_halt 403, "unable to resolve hostname for ip address #{ip}\n\n#{e.message}"
        end

        if forward_verify
          begin
            forward = dns.getaddresses(fqdn)
          rescue Resolv::ResolvError => e
            log_halt 403, "could not forward verify the remote hostname - #{fqdn} (#{ip})\n\n#{e.message}"
          end

          if forward.include?(ip)
            fqdn
          else
            log_halt 403, "untrusted client has no matching forward DNS lookup - #{fqdn} (#{ip})"
          end
        else
          fqdn
        end
      end

      def parse_openssl_cert(certificate_raw)
        return if certificate_raw.nil? || certificate_raw.empty?

        OpenSSL::X509::Certificate.new(certificate_raw)
      end

      def get_cn_from_certificate(certificate)
        return unless certificate&.subject

        cn = certificate.subject.to_a.find { |oid| oid == 'CN' }
        return unless cn

        cn[2]
      end
    end

    def authorize!
      include Helpers

      before do
        do_authorize_with_any
      end
    end

    def authorize_with_trusted_hosts
      include Helpers

      before do
        do_authorize_with_trusted_hosts
      end
    end

    def authorize_with_ssl_client
      include Helpers

      before do
        do_authorize_with_ssl_client
      end
    end
  end
end
