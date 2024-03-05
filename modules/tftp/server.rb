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

  class Pxegrub2targetos < Server
    def setup_bootloader(mac, os)
      FileUtils.mkdir_p(pxeconfig_dir(mac))
      FileUtils.cp "/usr/local/share/bootloader-universe/#{os}/shimx64.efi", pxeconfig_dir(mac) + "shimx64.efi"
      FileUtils.cp "/usr/local/share/bootloader-universe/#{os}/grubx64.efi", pxeconfig_dir(mac) + "grubx64.efi"
      File.open(pxeconfig_dir(mac) + "/targetos", 'w') { |f| f.write(os) }
    end

    def pxeconfig_dir(mac)
      "#{path}/grub2/" + mac.tr(':', '-').downcase + "/"
    end

    def pxe_default(mac)
      ["#{pxeconfig_dir}/grub.cfg", "#{pxeconfig_dir(mac)}/grub.cfg"]
    end

    def pxeconfig_file(mac)
      ["#{pxeconfig_dir(mac)}/grub.cfg", "#{pxeconfig_dir(mac)}/grub.cfg-01-" + mac.tr(':', '-').downcase, "#{pxeconfig_dir(mac)}/grub.cfg-#{mac.downcase}"]
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
end
