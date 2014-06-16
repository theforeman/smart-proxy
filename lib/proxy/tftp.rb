require 'fileutils'
require 'pathname'
require "proxy/util"

module Proxy::TFTP

  class Tftp
    include Proxy::Log
    # Creates TFTP pxeconfig file
    def set mac, config
      raise "Invalid parameters received" if mac.nil? or config.nil?

      FileUtils.mkdir_p pxeconfig_dir

      File.open(pxeconfig_file(mac), 'w') {|f| f.write(config) }
      logger.info "TFTP: entry for #{mac} created successfully"
    end

    # Removes pxeconfig files
    def del mac
      file = pxeconfig_file(mac)
      if File.exists?(file)
        FileUtils.rm_f file
        logger.debug "TFTP: entry for #{mac} removed successfully"
      else
        logger.info "TFTP: Skipping a request to delete a file which doesn't exists"
      end
    end

    # Gets the contents of a pxeconfig file
    def get mac
      file = pxeconfig_file(mac)
      if File.exists?(file)
        config = File.open(pxeconfig_file(mac), 'r') {|f| f.readlines }
        logger.debug "TFTP: entry for #{mac} read successfully"
      else
        logger.info "TFTP: Skipping a request to read a file which doesn't exists"
        raise "File #{file} not found"
      end
      config
    end

    # Creates a default menu file
    def create_default config
      raise "Default config not supplied" if config.nil?

      FileUtils.mkdir_p File.dirname pxe_default
      File.open(pxe_default, 'w') {|f| f.write(config) }
      logger.info "TFTP: #{pxe_default} entry created successfully"
    end

    protected
    # returns the absolute path
    def path(p = nil)
      p ||= SETTINGS.tftproot || File.expand_path(File.dirname(__FILE__)) + "/tftpboot"
      # are we running in RAILS or as a standalone CGI?
      dir = defined?(RAILS_ROOT) ? RAILS_ROOT : File.expand_path(File.dirname(__FILE__))
      return (p =~ /^\//) ? p : Pathname.new(dir).join(p).to_s
    end
  end

  class Syslinux < Tftp
    def pxeconfig_dir
      "#{path}/pxelinux.cfg"
    end
    def pxe_default
      "#{pxeconfig_dir}/default"
    end
    def pxeconfig_file mac
      "#{pxeconfig_dir}/01-"+mac.gsub(/:/,"-").downcase
    end
  end

  class Pxegrub < Tftp
    def pxeconfig_dir
      "#{path}"
    end
    def pxe_default
      "#{pxeconfig_dir}/boot/grub/menu.lst"
    end
    def pxeconfig_file mac
      "#{pxeconfig_dir}/menu.lst.01"+mac.gsub(/:/,"").upcase
    end
  end

  class Ztp < Tftp
    def pxeconfig_dir
      "#{path}/ztp.cfg"
    end
    def pxe_default
      pxeconfig_dir
    end
    def pxeconfig_file mac
      "#{pxeconfig_dir}/"+mac.gsub(/:/,"").upcase
    end
  end

  class << self
    include Proxy::Util
    def fetch_boot_file dst, src
      filename    = dst + '-' + src.split("/")[-1]
      destination = Pathname.new(File.expand_path(filename, SETTINGS.tftproot)).cleanpath
      tftproot    = Pathname.new(SETTINGS.tftproot).cleanpath
      raise "TFTP destination outside of tftproot" unless destination.to_s.start_with?(tftproot.to_s)

      # Ensure that our image directory exists
      # as the dst might contain another sub directory
      FileUtils.mkdir_p destination.parent

      wget = which("wget")
      cmd = "#{wget} --timeout=10 --tries=3 --no-check-certificate -nv -c \"#{escape_for_shell(src.to_s)}\" -O \"#{escape_for_shell(destination.to_s)}\""
      CommandTask.new(cmd)
    end
  end
end
