require 'openssl'
require 'resolv'

module Proxy::Helpers
  include Proxy::Log

  # Accepts a html error code and a message, which is then returned to the caller after adding to the proxy log
  # OR  a block which is executed and its errors handled in a similar way.
  # If no code is supplied when the block is declared then the html error used is 400.
  def log_halt code=nil, exception=nil
    message = exception.is_a?(String) ? exception : exception.to_s
    begin
      if block_given?
        return yield
      end
    rescue => e
      message += e.message
      code     = code || 400
    end
    content_type :json if request.accept?("application/json")
    logger.error message
    logger.debug exception.backtrace.join("\n") if exception.is_a?(Exception)
    halt code, message
  end

  # read the HTTPS client certificate from the environment and extract its CN
  def https_cert_cn
    certificate_raw = request.env['SSL_CLIENT_CERT'].to_s
    log_halt 403, 'could not read client cert from environment' if certificate_raw.empty?

    begin
      certificate = OpenSSL::X509::Certificate.new certificate_raw
      if certificate.subject && certificate.subject.to_s =~ /CN=([^\s\/,]+)/i
        $1
      else
        log_halt 403, 'could not read CN from the client certificate'
      end
    rescue OpenSSL::X509::CertificateError => e
        log_halt 403, "could not parse the client certificate\n\n#{e.message}"
    end
  end

  # reverse lookup an IP address while verifying it via forward resolv
  def remote_fqdn(forward_verify=true)
    ip = request.env['REMOTE_ADDR']
    log_halt 403, 'could not get remote address from environment' if ip.empty?

    begin
      dns = Resolv.new
      fqdn = dns.getname(ip)
    rescue Resolv::ResolvError => e
      log_halt 403, "unable to resolve hostname for ip address #{ip}\n\n#{e.message}"
    end

    unless forward_verify
      fqdn
    else
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
    end
  end

end
