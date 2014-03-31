require 'net/http'
require 'net/https'
require 'uri'
require 'proxy/log'

module Proxy::AbrtProxy
  def self.random_alpha_string(length)
    base = ('a'..'z').to_a
    result = ""
    length.times { result << base[rand(base.size)] }
    result
  end

  # Generate multipart boundary separator
  def self.suggest_separator
      separator = "-"*28
      separator + self.random_alpha_string(16)
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
    response = http.start { |con| con.post(path, body, headers) }

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

  class HostReport
    include Proxy::Log

    class AggregatedReport
      attr_accessor :report, :count, :hash
      def initialize(report, count, hash)
        @report = report
        @count = count
        @hash = hash
      end
    end

    class Error < RuntimeError; end

    attr_reader :host, :reports, :files, :by_hash

    def initialize(fname)
      contents = IO.read(fname)
      json = JSON.parse(contents)

      report = json["report"]
      hash = HostReport.duphash report
      ar = AggregatedReport.new(json["report"], 1, hash)
      @reports = [ar]
      # index the array elements by duphash, if they have one
      @by_hash = {}
      @by_hash[hash] = ar unless hash.nil?
      @files = [fname]
      @host = json["host"]
    end

    def merge(other)
      raise HostReport::Error, "Host names do not match" unless @host == other.host

      other.reports.each do |ar|
        if !ar.hash.nil? && @by_hash.has_key?(ar.hash)
          # we already have this report, just increment the counter
          @by_hash[ar.hash].count += ar.count
        else
          # we either don't have this report or it has no hash
          @reports << ar
          @by_hash[ar.hash] = ar unless ar.hash.nil?
        end
      end
      @files += other.files
    end

    def send_to_foreman
      foreman_report = create_foreman_report
      logger.debug "Sending #{foreman_report}"
      Proxy::Request::Reports.new.post_report(foreman_report.to_json)
    end

    def unlink
      @files.each do |fname|
        logger.debug "Deleting #{fname}"
        File.unlink(fname)
      end
    end

    def self.save(host, report)
      # create the spool dir if it does not exist
      FileUtils.mkdir_p HostReport.spooldir
      on_disk_report = { "host" => host, "report" => report }

      # write report to temporary file
      temp_fname = with_unique_filename "new-" do |temp_fname|
        File.open temp_fname, File::WRONLY|File::CREAT|File::EXCL do |tmpfile|
          tmpfile.write(on_disk_report.to_json)
        end
      end

      # rename it
      with_unique_filename ("ureport-" + DateTime.now.iso8601 + "-") do |final_fname|
        File.link temp_fname, final_fname
        File.unlink temp_fname
      end
    end

    def self.load_from_spool
      reports = []
      report_files = Dir[File.join(HostReport.spooldir, "ureport-*")]
      report_files.each do |fname|
        begin
          reports << new(fname)
        rescue StandardError => e
          logger.error "Failed to parse report #{fname}: #{e}"
        end
      end
      reports
    end

    private

    def failed_reports_count
      @reports.inject(0) { |total,ar| total += ar.count }
    end

    def report_logs
      @reports.collect do |ar|
        message = ar.report["reason"]
        message << " (repeated #{ar.count} times)" if ar.count > 1
        { "log" => { "sources"  => { "source" => "ABRT" },
                     "messages" => { "message" => message },
                     "level"    => "err"
                   }
        }
      end
    end

    # http://projects.theforeman.org/projects/foreman/wiki/Json-report-format
    # To be replaced once Foreman understands other report types than from Puppet.
    def create_foreman_report
      { "report" => {
            "host"        => @host,
            "reported_at" => Time.now.utc.to_s,
            "status"      => { "applied"         => 0,
                               "restarted"       => 0,
                               "failed"          => failed_reports_count,
                               "failed_restarts" => 0,
                               "skipped"         => 0,
                               "pending"         => 0
                             },
            "metrics"     => { "resources" => { "total" => 0 },
                               "time"      => { "total" => 0 }
                             },
            "logs"        => report_logs
            }
      }
    end

    def self.duphash(report)
      return nil if !SETTINGS.abrt_aggregate_reports

      begin
        satyr_report = Satyr::Report.new report.to_json
        stacktrace = satyr_report.stacktrace
        thread = stacktrace.find_crash_thread
        thread.duphash
      rescue StandardError => e
        logger.error "Error computing duphash: #{e}"
        nil
      end
    end

    def self.unique_filename(prefix)
      File.join(HostReport.spooldir, prefix + Proxy::AbrtProxy::random_alpha_string(8))
    end

    def self.with_unique_filename(prefix)
      filename = unique_filename prefix
      tries_left = 5
      begin
        yield filename
      rescue Errno::EEXIST => e
        filename = unique_filename prefix
        tries_left -= 1
        retry if tries_left > 0
        raise HostReport::Error, "Unable to create unique file"
      end
      filename
    end

    def self.spooldir
      SETTINGS.abrt_spooldir || File.join(APP_ROOT, "spool/abrt-send")
    end
  end
end
