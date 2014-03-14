require 'net/http'
require 'net/https'
require 'uri'

module Proxy::AbrtProxy
  extend Proxy::Log

  # Generate multipart boundary separator
  def self.suggest_separator
      separator = "-"*28
      base = ('a'..'z').to_a
      16.times { separator << base[rand(base.size)] }
      separator
  end

  # It seems that Net::HTTP does not support multipart/form-data - this function
  # is adapted from http://stackoverflow.com/a/213276 and lib/proxy/request.rb
  def self.form_data_file(content, file_content_type)
    # Assemble the request body using the special multipart format
    thepart =  "Content-Disposition: form-data; name=\"file\"; filename=\"*buffer*\"\r\n" +
               "Content-Type: #{ file_content_type }\r\n\r\n#{ content }\r\n"

    boundary = self.suggest_separator
    while thepart.include? boundary
      boundary = self.suggest_separator
    end

    body = "--" + boundary + "\r\n" + thepart + "--" + boundary + "--\r\n"
    headers = {
      "User-Agent"     => "foreman-proxy/#{Proxy::VERSION}",
      "Content-Type"   => "multipart/form-data; boundary=#{ boundary }",
      "Content-Length" => body.length.to_s
    }

    return headers, body
  end

  def self.faf_request(path, content, content_type="application/json")
    uri              = URI.parse(SETTINGS.abrt_server_url.to_s)
    http             = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = uri.scheme == 'https'
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    if SETTINGS.abrt_server_ssl_noverify
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    if SETTINGS.abrt_server_ssl_cert && !SETTINGS.abrt_server_ssl_cert.to_s.empty? \
        && SETTINGS.abrt_server_ssl_key && !SETTINGS.abrt_server_ssl_key.to_s.empty?
      http.cert = OpenSSL::X509::Certificate.new(File.read(SETTINGS.abrt_server_ssl_cert))
      http.key  = OpenSSL::PKey::RSA.new(File.read(SETTINGS.abrt_server_ssl_key), nil)
    end

    headers, body = self.form_data_file content, content_type

    path = [uri.path, path].join unless uri.path.empty?
    begin
      response = http.start { |con| con.post(path, body, headers) }
    rescue SystemCallError => e
      # FAF unreachable
      logger.error e
      return nil
    end

    response
  end

  def self.common_name(request)
    client_cert = request.env['SSL_CLIENT_CERT']
    raise Proxy::Error::Unauthorized, "Client certificate required" if client_cert.to_s.empty?

    begin
      client_cert = OpenSSL::X509::Certificate.new(client_cert)
    rescue OpenSSL::OpenSSLError => e
      raise Proxy::Error::Unauthorized, e.message
    end

    cn = client_cert.subject.to_a.detect { |name, value| name == 'CN' }
    cn = cn[1] unless cn.nil?
    raise Proxy::Error::Unauthorized, "Common Name not found in the certificate" unless cn

    return cn
  end

  # http://projects.theforeman.org/projects/foreman/wiki/Json-report-format
  def self.create_report(host, ureport)
    message = ureport["reason"]
    { "report" => {
          "host"        => host,
          "reported_at" => Time.now.utc.to_s,
          "status"      => { "applied"         => 0,
                             "restarted"       => 0,
                             "failed"          => 1,
                             "failed_restarts" => 0,
                             "skipped"         => 0,
                             "pending"         => 0
                           },
          "metrics"     => { "resources" => { "total" => 0 },
                             "time"      => { "total" => 0 }
                           },
          "logs"        => [
                             { "log" => { "sources"  => { "source" => "ABRT" },
                                          "messages" => { "message" => message },
                                          "level"    => "err"
                                        }
                             }
                           ]
          }
    }
  end
end
