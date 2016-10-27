require 'uri'
require 'securerandom'
require 'digest'
require 'json'
require 'concurrent'

module Proxy::TFTP
  class HttpError < RuntimeError
    attr_reader :code, :message

    def initialize(code, message)
      @code = code
      @message = message
    end
  end

  class HttpDownload
    class Status
      attr_accessor :last_error, :timestamp, :stopped

      def initialize(now = Time.now)
        @m = Mutex.new
        @file_length = 0
        @downloaded = 0
        @timestamp = now
        @stopped = false
      end

      def file_length
        @m.synchronize { @file_length }
      end

      def downloaded
        @m.synchronize { @downloaded }
      end

      def file_length=(length)
        @m.synchronize { @file_length = length }
      end

      def update_downloaded(chunk_length)
        @m.synchronize { @downloaded += chunk_length }
      end

      def progress
        (fl = file_length) == 0 ? 0 : ((downloaded.to_f/fl) * 100).round(2).to_i
      end

      def reset_error
        @last_error = nil
      end

      def stopped?
        @stopped
      end

      def to_hash
        {:file_length => file_length, :downloaded => downloaded, :progress => progress, :timestamp => timestamp, :last_error => last_error}
      end
    end

    class Downloader
      ATTEMPT_DELAY = 10

      def initialize(parsed_url, dst_path, status)
        @stop = false
        @status = status
        @parsed_url = parsed_url
        @dst_path = dst_path
      end

      def size
        Net::HTTP.start(@parsed_url.host, @parsed_url.port, :use_ssl => @parsed_url.scheme == 'https') do |http|
          head = Net::HTTP::Head.new(@parsed_url)
          http.request(head) do |response|
            raise ::Proxy::TFTP::HttpError.new(response.code, response.message) unless response.is_a?(Net::HTTPSuccess)
            response['content-length'].to_i rescue 0
          end
        end
      end

      def start(start_position = 0)
        Net::HTTP.start(@parsed_url.host, @parsed_url.port, :use_ssl => @parsed_url.scheme == 'https') do |http|
          get = Net::HTTP::Get.new(@parsed_url, (range_header(start_position) if start_position != 0))
          http.request(get) do |response|
            raise ::Proxy::TFTP::HttpError.new(response.code, response.message) unless response.is_a?(Net::HTTPSuccess)
            @status.file_length = response['content-length'].to_i rescue 0
            @status.update_downloaded(start_position) if response.code == '206'
            open(@dst_path, (response.code == '206' ? 'ab' : 'wb')) do |io|
              if @stop
                @status.stopped = true
                break
              end
              response.read_body {|b| @status.update_downloaded(b.length); io.write(b)}
            end
          end
        end
      end

      def restart
        start(File.size?(@dst_path) || 0)
      end

      def range_header(range_start)
        {'Range' => "bytes=#{range_start}-"}
      end

      def stop
        @stop = true
      end
    end

    attr_reader :status, :m

    def initialize(dst_path, url, status = Status.new)
      @status = status
      @dst = dst_path
      @url = URI.parse(url)
      @downloader = nil
      @m = Mutex.new
    end

    def is_local_copy_stale?(filepath)
      return true unless File.exist?(filepath)
      to_return = Concurrent::Promise.new { new_downloader.size }
                                     .on_success { |result| result == 0 || result != File.size(filepath) }
                                     .on_error { true }
                                     .execute
                                     .value(10) # don't block for too long on the check, fail it if we don't receive a response in 10 seconds
      to_return.nil? ? true : to_return # Concurrent::Promise#value returns nil if the promise is in 'pending' state
    end

    def restart_download
      Concurrent::Promise.new { new_downloader.restart }
                         .on_error {|reason| attempt_restart(reason, 1) }
                         .on_error {|reason| attempt_restart(reason, 2) }
                         .on_error {|reason| attempt_restart(reason, 3) }
    end

    def download
      Concurrent::Promise.new { new_downloader.start }
                         .on_error {|reason| attempt_restart(reason, 1) }
                         .on_error {|reason| attempt_restart(reason, 2) }
                         .on_error {|reason| attempt_restart(reason, 3) }
    end

    def attempt_restart(reason, attempt_number)
      case reason
        when Errno::ECONNREFUSED
        when Errno::ECONNRESET
        when Errno::EHOSTUNREACH
        when Errno::ETIMEDOUT
        when ::Proxy::TFTP::HttpError
          # retry on server error or http request timeout
          if reason.code == 500 || reason.code == 408
            sleep(attempt_number * ATTEMPT_DELAY * 3)
            new_downloader.restart
          elsif reason.code == 416
            # no need to delay the download attempt -- the problem is with range header, not connection
            new_downloader.start
          else
            raise reason
          end
        else
          raise reason
      end
    end

    def new_downloader
      m.synchronize { @status = Status.new; @downloader = Downloader.new(@url, @dst, @status) }
    end

    def stop
      m.synchronize { @downloader.stop }
    end
  end

  class HttpDownloads
    include ::Proxy::Log

    CLEANUP_INTERVAL = 60*60*2 # 2 hours

    # download_in_progress is used in tests only
    attr_reader :m, :url_to_download, :id_to_download, :downloader_class, :download_in_progress

    def initialize(dst_dir, downloader_class = HttpDownload)
      @url_to_download = {}
      @id_to_download = {}
      @dst_dir = Pathname.new(dst_dir).cleanpath.to_s
      @downloader_class = downloader_class
      @m = Mutex.new
    end

    def start
      @cleanup_task ||= schedule_id_to_download_cleanup
      restart_downloads
    end

    def stop
      @cleanup_task.cancel unless @cleanup_task.nil?
      m.synchronize { id_to_download.values.each {|d| d.stop}}
    end

    def status(id)
      m.synchronize { id_to_download.key?(id) ? id_to_download[id].status : nil }
    end

    def restart_downloads
      interrupted_downloads = Dir.glob(File.join(@dst_dir, '**', "*.metadata"))
      interrupted_downloads.each do |path|
        begin
          filepath = remove_file_extention(remove_file_extention(path))
          tmp_filepath = remove_file_extention(path) + '.tmp'
          parsed_metadata = JSON.parse(IO.read(path))
          do_download(filepath, tmp_filepath, path, parsed_metadata['url'], parsed_metadata['id'], true)
        rescue Exception => e
          logger.error("Error restarting download '#{filepath}'", e)
        end
      end
    end

    def download(prefix, src_url)
      filepath = filepath(prefix, src_url)
      raise "TFTP destination outside of tftproot" unless filepath.to_s.start_with?(@dst_dir)
      tmp_filepath = filepath + tmp_filepath_postfix(src_url)
      metadata_filepath = filepath + metadata_filepath_postfix(src_url)
      return unless downloader_class.new(tmp_filepath, src_url).is_local_copy_stale?(filepath)
      do_download(filepath, tmp_filepath, metadata_filepath, src_url)
    end

    def do_download(filepath, tmp_filepath, metadata_filepath, src_url, id = SecureRandom.hex(12), restart = false)
      m.synchronize do
        begin
          return url_to_download[src_url] if url_to_download.key?(src_url)
          unless restart
            FileUtils.mkdir_p(Pathname.new(filepath).parent)
            create_metadata(metadata_filepath, src_url, id)
          end
          start_or_restart_download(filepath, tmp_filepath, metadata_filepath, src_url, id, restart)
          id
        rescue Exception => e
          logger.debug("Error creating metadata for download from '#{src_url}'", e)
          remove_file(metadata_filepath)
          remove_file(tmp_filepath)
          raise e
        end
      end
    end

    def start_or_restart_download(filepath, tmp_filepath, metadata_filepath, src_url, id, restart)
      download_in_progress = downloader_class.new(tmp_filepath, src_url)

      url_to_download[src_url] = id
      id_to_download[id] = download_in_progress

      @download_in_progress =
        (restart ? download_in_progress.restart_download : download_in_progress.download)
        .on_success do
          unless download_in_progress.status.stopped?
            logger.debug("Successfully downloaded '#{src_url}'")
            File.rename(tmp_filepath, filepath)
            remove_file(metadata_filepath)
          end
        end
        .on_error do |reason|
          logger.debug("Error when downloading '#{src_url}'", reason)
          download_in_progress.status.last_error = reason
          remove_file(tmp_filepath)
          remove_file(metadata_filepath)
        end
        .then { m.synchronize { url_to_download.delete(src_url) }}
        .execute
    end

    def filepath(prefix, src_url)
      File.expand_path(boot_filename(prefix, src_url), @dst_dir)
    end

    def tmp_filepath_postfix(src_url)
      ".%s.tmp" % [Digest::MD5.new.update(src_url).hexdigest]
    end

    def remove_file_extention(path)
      (dot_index = path.rindex('.')).nil? ? path : path.slice(0..(dot_index-1))
    end

    def remove_file(file_path)
      File.delete(file_path)
    rescue Exception #rubocop:disable HandleExceptions
      # do nothing
    end
    #rubocop:enable HandleExceptions

    def metadata_filepath_postfix(src_url)
      ".%s.metadata" % [Digest::MD5.new.update(src_url).hexdigest]
    end

    def create_metadata(path, src_url, id)
      open(path, 'w') {|f| f.write({:url => src_url, :id => id}.to_json)}
    end

    def boot_filename(dst, src)
      # Do not append a '-' if the dst is a directory path
      dst.end_with?('/') ? dst + src.split("/")[-1] : dst + '-' + src.split("/")[-1]
    end

    def cleanup_id_to_download(now = Time.now)
      m.synchronize do
        logger.debug("Cleaning up old download results")
        id_to_download.delete_if {|_, d| d.status.timestamp + 2*60*60*24 > now }
      end
    end

    def schedule_id_to_download_cleanup
      Concurrent::ScheduledTask.new(CLEANUP_INTERVAL) { cleanup_id_to_download; @cleanup_task = schedule_id_to_download_cleanup }.execute
    end
  end
end
