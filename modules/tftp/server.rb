require 'fileutils'
require 'pathname'

module Proxy::TFTP
  class Server
    include Proxy::Log
    # Creates TFTP pxeconfig file
    def set mac, config
      raise "Invalid parameters received" if mac.nil? || config.nil?
      pxeconfig_file(mac).each do |file|
        write_file file, config
      end
      true
    end

    # Removes pxeconfig files
    def del mac
      pxeconfig_file(mac).each do |file|
        delete_file file
      end
      true
    end

    # Gets the contents of one of pxeconfig files
    def get mac
      file = pxeconfig_file(mac).first
      read_file(file)
    end

    # Creates a default menu file
    def create_default config
      raise "Default config not supplied" if config.nil?
      pxe_default.each do |file|
        write_file file, config
      end
      true
    end

    # returns the absolute path
    def path(p = nil)
      p ||= Proxy::TFTP::Plugin.settings.tftproot
      return (p =~ /^\//) ? p : Pathname.new(File.expand_path(File.dirname(__FILE__))).join(p).to_s
    end

    def read_file(file)
      raise("File #{file} not found") unless File.exist?(file)
      File.open(file, 'r') {|f| f.readlines }
    end

    def write_file(file, contents)
      FileUtils.mkdir_p(File.dirname(file))
      File.open(file, 'w') {|f| f.write(contents)}
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
    def pxeconfig_file mac
      ["#{pxeconfig_dir}/01-"+mac.gsub(/:/,"-").downcase]
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
    def pxeconfig_file mac
      ["#{pxeconfig_dir}/menu.lst.01"+mac.gsub(/:/,"").upcase, "#{pxeconfig_dir}/01-"+mac.gsub(/:/,'-').upcase]
    end
  end

  class Pxegrub2 < Server
    def pxeconfig_dir
      "#{path}/grub2"
    end
    def pxe_default
      ["#{pxeconfig_dir}/grub.cfg"]
    end
    def pxeconfig_file mac
      ["#{pxeconfig_dir}/grub.cfg-"+mac.gsub(/:/,'-').downcase]
    end
  end

  class Ztp < Server
    def pxeconfig_dir
      "#{path}/ztp.cfg"
    end
    def pxe_default
      [pxeconfig_dir]
    end
    def pxeconfig_file mac
      ["#{pxeconfig_dir}/"+mac.gsub(/:/,"").upcase]
    end
  end

  class Poap < Server
    def pxeconfig_dir
      "#{path}/poap.cfg"
    end
    def pxe_default
      [pxeconfig_dir]
    end
    def pxeconfig_file mac
      ["#{pxeconfig_dir}/"+mac.gsub(/:/,"").upcase]
    end
  end

  def self.fetch_boot_file dst, src
    filename    = boot_filename(dst, src)
    destination = Pathname.new(File.expand_path(filename, Proxy::TFTP::Plugin.settings.tftproot)).cleanpath
    tftproot    = Pathname.new(Proxy::TFTP::Plugin.settings.tftproot).cleanpath
    raise "TFTP destination outside of tftproot" unless destination.to_s.start_with?(tftproot.to_s)

    # Ensure that our image directory exists
    # as the dst might contain another sub directory
    FileUtils.mkdir_p destination.parent

    ::Proxy::HttpDownload.new(src.to_s, destination.to_s).start
  end

  def self.boot_filename(dst, src)
    # Do not append a '-' if the dst is a directory path
    dst.end_with?('/') ? dst + src.split("/")[-1] : dst + '-' + src.split("/")[-1]
  end
end
