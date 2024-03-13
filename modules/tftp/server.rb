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

    def delete_dir(dir)
      if Dir.exist?(dir)
        FileUtils.rm_rf dir
        logger.debug "TFTP: #{dir} removed successfully"
      else
        logger.debug "TFTP: Skipping a request to delete a directory which doesn't exists"
      end
    end

    def setup_bootloader(mac, os, major, minor, arch, bootfilename_efi, build)
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
    def bootloader_path(os, version, arch)
      unless (bootloader_universe = Proxy::TFTP::Plugin.settings.bootloader_universe)
        logger.debug "TFTP: bootloader universe not configured."
        return
      end

      bootloader_path = "#{bootloader_universe}/pxegrub2/#{os}/#{version}/#{arch}"

      logger.debug "TFTP: Checking bootloader universe for suitable bootloader directory for"
      logger.debug "TFTP:   * Operating system: #{os}"
      logger.debug "TFTP:   * Version: #{version}"
      logger.debug "TFTP:   * Architecture: #{arch}"
      logger.debug "TFTP: Checking bootloader universe if \"#{bootloader_path}\" exists."
      unless Dir.exist?(bootloader_path)
        logger.debug "TFTP: Directory \"#{bootloader_path}\" does not exist."

        bootloader_path = "#{bootloader_universe}/pxegrub2/#{os}/default/#{arch}"
        logger.debug "TFTP: Checking if fallback directory at \"#{bootloader_path}\" exists."
        unless Dir.exist?(bootloader_path)
          logger.debug "TFTP: Directory \"#{bootloader_path}\" does not exist."
          return
        end
      end

      bootloader_path
    end

    def setup_bootloader(mac, os, major, minor, arch, bootfilename_efi, build)
      pxeconfig_dir_mac = pxeconfig_dir(mac)

      if build == "true"
        logger.debug "TFTP: Host is in build mode."
        logger.debug "TFTP:   => Deploying host specific bootloader files to \"#{pxeconfig_dir_mac}\""

        FileUtils.mkdir_p(pxeconfig_dir_mac)

        version = "#{major}#{".#{minor}" unless minor.empty?}"
        bootloader_path = bootloader_path(os, version, arch)

        if bootloader_path
          logger.debug "TFTP: Copying bootloader files from bootloader universe:"
          logger.debug "TFTP:   - \"#{bootloader_path}/*\" => \"#{pxeconfig_dir_mac}/\""
          FileUtils.cp_r("#{bootloader_path}/.", "#{pxeconfig_dir_mac}/", remove_destination: true)
        else
          logger.debug "TFTP: Copying default bootloader files:"
          logger.debug "TFTP:   - \"#{pxeconfig_dir}/grub#{bootfilename_efi}.efi\" => \"#{pxeconfig_dir_mac}/grub#{bootfilename_efi}.efi\""
          logger.debug "TFTP:   - \"#{pxeconfig_dir}/shim#{bootfilename_efi}.efi\" => \"#{pxeconfig_dir_mac}/shim#{bootfilename_efi}.efi\""
          logger.debug "TFTP:   - \"#{pxeconfig_dir}/grub#{bootfilename_efi}.efi\" => \"#{pxeconfig_dir_mac}/boot.efi\""
          logger.debug "TFTP:   - \"#{pxeconfig_dir}/shim#{bootfilename_efi}.efi\" => \"#{pxeconfig_dir_mac}/boot-sb.efi\""
          FileUtils.cp_r("#{pxeconfig_dir}/grub#{bootfilename_efi}.efi", "#{pxeconfig_dir_mac}/grub#{bootfilename_efi}.efi", remove_destination: true)
          FileUtils.cp_r("#{pxeconfig_dir}/shim#{bootfilename_efi}.efi", "#{pxeconfig_dir_mac}/shim#{bootfilename_efi}.efi", remove_destination: true)
          FileUtils.cp_r("#{pxeconfig_dir}/grub#{bootfilename_efi}.efi", "#{pxeconfig_dir_mac}/boot.efi", remove_destination: true)
          FileUtils.cp_r("#{pxeconfig_dir}/shim#{bootfilename_efi}.efi", "#{pxeconfig_dir_mac}/boot-sb.efi", remove_destination: true)
        end

        File.write(File.join(pxeconfig_dir_mac, 'os_info'), "#{os} #{version} #{arch}")
      else
        logger.debug "TFTP: Host is not in build mode."
        logger.debug "TFTP:   => Removing host specific bootloader files from \"#{pxeconfig_dir_mac}\""

        FileUtils.rm_f(Dir.glob("#{pxeconfig_dir_mac}/*.efi"))
      end
    end

    def del(mac)
      super mac
      delete_dir "#{path}/host_config/#{mac.tr(':', '-').downcase}"
    end

    def pxeconfig_dir(mac = nil)
      "#{path}#{mac ? "/host_config/#{mac.tr(':', '-').downcase}" : ''}/grub2"
    end

    def pxe_default
      ["#{pxeconfig_dir}/grub.cfg"]
    end

    def pxeconfig_file(mac)
      pxeconfig_dir_mac = pxeconfig_dir(mac)
      ["#{pxeconfig_dir_mac}/grub.cfg", "#{pxeconfig_dir_mac}/grub.cfg-01-#{mac.tr(':', '-').downcase}", "#{pxeconfig_dir_mac}/grub.cfg-#{mac.downcase}", "#{pxeconfig_dir}/grub.cfg-01-" + mac.tr(':', '-').downcase, "#{pxeconfig_dir}/grub.cfg-#{mac.downcase}"]
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
