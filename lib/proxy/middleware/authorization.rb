module Proxy
  module Middleware
    class Authorization
      include ::Proxy::Log

      def initialize(app)
        @app = app
      end

      def call(env)
        if https?(env)
          certificate_raw = https_client_cert_raw(env)
          return unauthorized if certificate_raw.empty?

          if trusted_hosts?
            begin
              certificate = OpenSSL::X509::Certificate.new(certificate_raw)
            rescue OpenSSL::X509::CertificateError => e
              logger.warn("Could not parse the client certificate: #{e.message}")
              return unauthorized
            end

            fqdn = get_cn_from_certificate(certificate)
            unless fqdn
              logger.warn('Could not read CN from the client certificate')
              return unauthorized
            end

            return denied(fqdn) unless trusted_host?(fqdn)
          end
        elsif trusted_hosts?
          return denied(fqdn) unless trusted_host?(remote_fqdn)
        end

        @app.call(env)
      end

      private

      def settings
        Proxy::SETTINGS
      end

      def unauthorized
        [401, {}, ['Unauthorized']]
      end

      def denied(fqdn)
        path = request.path_info # TODO
        logger.warn("Untrusted client #{fqdn} attempted to access #{path}. Check :trusted_hosts: in settings.yml")
        [403, {}, ['Denied']]
      end

      def https?(env)
        ['yes', 'on', 1].include?(env['HTTPS'].to_s)
      end

      def https_client_cert_raw(env)
        env['SSL_CLIENT_CERT'].to_s
      end

      def trusted_hosts?
        settings.trusted_hosts
      end

      def trusted_host?(fqdn)
        logger.debug "verifying remote client #{fqdn} against trusted_hosts #{trusted_hosts}"
        trusted_hosts.include?(fqdn.downcase)
      end

      # reverse lookup an IP address while verifying it via forward resolv
      def remote_fqdn
        ip = env['REMOTE_ADDR']
        log_halt 403, 'could not get remote address from environment' if ip.empty?

        begin
          dns = resolv
          fqdn = dns.getname(ip)
        rescue Resolv::ResolvError => e
          log_halt 403, "unable to resolve hostname for ip address #{ip}\n\n#{e.message}"
        end

        if settings.forward_verify
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

      def get_cn_from_certificate(certificate)
        return unless certificate&.subject

        cn = certificate.subject.to_a.find { |oid| oid == 'CN' }
        return unless cn

        cn[2]
      end
    end
  end
end
