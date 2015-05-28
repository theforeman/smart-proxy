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
      exception = e
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

  # parses the body as json and returns a hash of the body
  # returns empty hash if there is a json parse error or body is empty
  # request.env["CONTENT_TYPE"] must contain application/json in order for the json to be parsed
  def parse_json_body
    json_data = {}
    # if the user has explicitly set the content_type then there must be something worth decoding
    # we use a regex because it might contain something else like: application/json;charset=utf-8
    # by default the content type will probably be set to "application/x-www-form-urlencoded" unless the
    # user changed it.  If the user doesn't specify the content type we just ignore the body since a form
    # will be parsed into the request.params object for us by sinatra
    if request.env["CONTENT_TYPE"] =~ /application\/json/
      begin
        body_parameters = request.body.read
        json_data = JSON.parse(body_parameters)
      rescue => e
        log_halt 415, "Invalid JSON content in body of request: \n#{e.message}"
      end
    end
    json_data
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
