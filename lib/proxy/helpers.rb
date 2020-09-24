require 'openssl'
require 'proxy/logging_resolv'

module Proxy::Helpers
  include Proxy::Log

  # Accepts a html error code and a message, which is then returned to the caller after adding to the proxy log
  # OR  a block which is executed and its errors handled in a similar way.
  # If no code is supplied when the block is declared then the html error used is 400.
  def log_halt(code = nil, exception_or_msg = nil, custom_msg = nil)
    message = exception_or_msg.to_s
    message = "#{custom_msg}: #{message}" if custom_msg
    exception = exception_or_msg.is_a?(Exception) ? exception_or_msg : Exception.new(exception_or_msg)
    # just in case exception is passed in the 3rd parameter let's not loose the valuable info
    exception = custom_msg.is_a?(Exception) ? custom_msg : exception
    begin
      if block_given?
        return yield
      end
    rescue => e
      exception = e
      message += e.message
      code ||= 400
    end
    content_type :json if request.accept?("application/json")
    logger.error message, exception
    logger.exception(message, exception) if exception.is_a?(Exception)
    halt code, message
  end

  # read the HTTPS client certificate from the environment and extract its CN
  def https_cert_cn(request)
    certificate_raw = ssl_client_cert(request)
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
  # returns empty hash if there is a json parse error, the body is empty or is not a hash
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

      log_halt 415, "Invalid JSON content in body of request: data must be a hash, not #{json_data.class.name}" unless json_data.is_a?(Hash)
    end
    json_data
  end

  def dns_resolv(*args)
    resolv = Resolv::DNS.new(*args)
    resolv.timeouts = Proxy::SETTINGS.dns_resolv_timeouts
    ::Proxy::LoggingResolv.new(resolv)
  end

  def resolv(*args)
    ::Proxy::LoggingResolv.new(Resolv.new(*args))
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

  def ssl_client_cert(request)
    if request.env.key?('SSL_CLIENT_CERT')
      request.env['SSL_CLIENT_CERT'].to_s
    elsif request.env.key?('puma.peercert')
      request.env['puma.peercert'].to_s
    else
      ''
    end
  end

  def https?(request)
    # test env variable for puma and also webrick
    request.env['HTTPS'].to_s == 'https' || request.env['HTTPS'].to_s =~ /yes|on|1/
  end
end
