require 'fileutils'
require 'pathname'

module Proxy::TFTP
  extend Proxy::Log

  class Server
    include Proxy::Log
    # Creates TFTP pxeconfig file
    def set(mac, config)
      raise "Invalid parameters received" if mac.nil? || config.nil?
      pxeconfig_file(mac).each do |file|
        write_file file, config
      end
      true
    end

    # Removes pxeconfig files
    def del(mac)
      pxeconfig_file(mac).each do |file|
        delete_file file
      end
      true
    end

    # Gets the contents of one of pxeconfig files
    def get(mac)
      file = pxeconfig_file(mac).first
      read_file(file)
    end

    # Creates a default menu file
    def create_default(config)
      raise "Default config not supplied" if config.nil?
      pxe_default.each do |file|
        write_file file, config
      end
      true
    end

    # returns the absolute path
    def path(p = nil)
      p ||= Proxy::TFTP::Plugin.settings.tftproot
      (p =~ /^\//) ? p : Pathname.new(__dir__).join(p).to_s
    end

    def read_file(file)
      raise("File #{file} not found") unless File.exist?(file)
      File.open(file, 'r', &:readlines)
    end

    def write_file(file, contents)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, 'w') { |f| f.write(contents) }
      logger.debug "TFTP: #{file} created successfully"
    end

    def delete_file(file)
      if File.exist?(file)
        FileUtils.rm_f file
        logger.debug "TFTP: #{file} removed successfully"
      else
        logger.debug "TFTP: Skipping a request to delete a file which doesn't exists"
      end
    end
  end

  class Syslinux < Server
    def pxeconfig_dir
      "#{path}/pxelinux.cfg"
    end

    def pxe_default
      ["#{pxeconfig_dir}/default"]
    end

    def pxeconfig_file(mac)
      ["#{pxeconfig_dir}/01-" + mac.tr(':', "-").downcase]
    end
  end
  class Pxelinux < Syslinux; end

  class Pxegrub < Server
    def pxeconfig_dir
      "#{path}/grub"
    end

    def pxe_default
      ["#{pxeconfig_dir}/menu.lst", "#{pxeconfig_dir}/efidefault"]
    end

    def pxeconfig_file(mac)
      ["#{pxeconfig_dir}/menu.lst.01" + mac.delete(':').upcase, "#{pxeconfig_dir}/01-" + mac.tr(':', '-').upcase]
    end
  end

  class Pxegrub2 < Server
    def pxeconfig_dir
      "#{path}/grub2"
    end

    def pxe_default
      ["#{pxeconfig_dir}/grub.cfg"]
    end

    def pxeconfig_file(mac)
      ["#{pxeconfig_dir}/grub.cfg-01-" + mac.tr(':', '-').downcase, "#{pxeconfig_dir}/grub.cfg-#{mac.downcase}"]
    end
  end

  class Ztp < Server
    def pxeconfig_dir
      "#{path}/ztp.cfg"
    end

    def pxe_default
      [pxeconfig_dir]
    end

    def pxeconfig_file(mac)
      ["#{pxeconfig_dir}/" + mac.delete(':').upcase, "#{pxeconfig_dir}/" + mac.delete(':').upcase + ".cfg"]
    end
  end

  class Poap < Server
    def pxeconfig_dir
      "#{path}/poap.cfg"
    end

    def pxe_default
      [pxeconfig_dir]
    end

    def pxeconfig_file(mac)
      ["#{pxeconfig_dir}/" + mac.delete(':').upcase]
    end
  end

  class Ipxe < Server
    def pxeconfig_dir
      "#{path}/pxelinux.cfg"
    end

    def pxe_default
      ["#{pxeconfig_dir}/default.ipxe"]
    end

    def pxeconfig_file(mac)
      ["#{pxeconfig_dir}/01-" + mac.tr(':', "-").downcase + ".ipxe"]
    end
  end

  def self.fetch_system_image(image_dst, url, files, tftp_path)
    # Build paths, verify parameter do not contain ".." (switch folder), and check existing files
    image_root = Pathname.new(Proxy::TFTP::Plugin.settings.system_image_root).cleanpath
    image_path = Pathname.new(File.expand_path(image_dst, image_root)).cleanpath
    tftproot = Pathname.new(Proxy::TFTP::Plugin.settings.tftproot).cleanpath
    raise_error_on_prohibited_path(image_root, image_path, image_dst)
    file_exists = File.exist? image_path
    extr_file_map = {}
    files.each do |file|
      extr_filename = boot_filename(tftp_path, file)
      extr_file_path = Pathname.new(File.expand_path(extr_filename, tftproot)).cleanpath
      raise_error_on_prohibited_path(tftproot, extr_file_path, file)
      file_exists = false unless File.exist? extr_file_path
      extr_file_map[file] = extr_file_path
    end

    if file_exists
      200 # Return 200 if all files exist already
    else
      fetch_system_image_worker(url, image_path, extr_file_map)
      202 # Return 202 if download process was triggered
    end
  end

  def self.fetch_system_image_worker(url, image_path, extr_file_map)
    lock_file = ".#{File.basename(image_path.sub_ext(''))}.lock"
    # Lock
    image_path.parent.mkpath
    lock = Proxy::FileLock.try_locking(File.join(File.dirname(image_path), lock_file))
    if lock.nil?
      raise IOError.new, "System image download and extraction is still in progress"
    end

    Thread.new(lock, url, image_path, extr_file_map) do |t_lock, t_url, t_image_path, t_extr_file_map|
      # Wait for download completion
      download_task = choose_protocol_and_fetch(t_url, t_image_path)
      if download_task.is_a?(FalseClass)
        logger.error "TFTP image download error: Is another process downloading it already?"
        Thread.stop
      end
      unless download_task.join == 0
        logger.error "TFTP image download error: Task did not complete"
        Thread.stop
      end

      t_extr_file_map.each do |file_in_image, extr_file|
        # Create destination directory and extract file from iso
        extr_file.parent.mkpath
        extract_task = ::Proxy::ArchiveExtract.new(t_image_path, file_in_image, extr_file).start
        logger.error "TFTP image file extraction error: #{file_in_image} => #{extr_file}" unless extract_task.join == 0
      end
    ensure
      # Unlock
      Proxy::FileLock.unlock(t_lock)
      File.unlink(t_lock)
    end
  end

  def self.fetch_boot_file(dst, src)
    filename    = boot_filename(dst, src)
    destination = Pathname.new(File.expand_path(filename, Proxy::TFTP::Plugin.settings.tftproot)).cleanpath
    tftproot    = Pathname.new(Proxy::TFTP::Plugin.settings.tftproot).cleanpath
    raise "TFTP destination outside of tftproot" unless destination.to_s.start_with?(tftproot.to_s)

    # Ensure that our image directory exists
    # as the dst might contain another sub directory
    FileUtils.mkdir_p destination.parent
    choose_protocol_and_fetch src, destination
  end

  def self.choose_protocol_and_fetch(src, destination)
    case URI(src).scheme
    when 'http', 'https', 'ftp'
      ::Proxy::HttpDownload.new(src.to_s, destination.to_s,
                                connect_timeout: Proxy::TFTP::Plugin.settings.tftp_connect_timeout,
                                verify_server_cert: Proxy::TFTP::Plugin.settings.verify_server_cert).start

    when 'nfs'
      logger.debug "NFS as a protocol for installation medium detected."
    else
      raise "Cannot fetch boot file, unknown protocol for medium source path: #{src}"
    end
  end

  def self.boot_filename(dst, src)
    # Do not append a '-' if the dst is a directory path
    dst.end_with?('/') ? dst + src.split("/")[-1] : dst + '-' + src.split("/")[-1]
  end

  def self.raise_error_on_prohibited_path(base_path, relative_path, error_parameter)
    if relative_path.expand_path.relative_path_from(base_path).to_s.start_with?('..')
      raise "File to extract from image contains up-directory: #{error_parameter}"
    end
  end
end
