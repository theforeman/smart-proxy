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

    def delete_host_dir(mac)
      host_dir = File.join(path, 'host-config', dashed_mac(mac).downcase)
      logger.debug "TFTP: Removing directory '#{host_dir}'."
      FileUtils.rm_rf host_dir
    end

    def setup_bootloader(mac:, os:, release:, arch:, bootfile_suffix:)
    end

    def dashed_mac(mac)
      mac.tr(':', '-')
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
      ["#{pxeconfig_dir}/01-" + dashed_mac(mac).downcase]
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
      ["#{pxeconfig_dir}/menu.lst.01" + mac.delete(':').upcase, "#{pxeconfig_dir}/01-" + dashed_mac(mac).upcase]
    end
  end

  class Pxegrub2 < Server
    def bootloader_path(os, release, arch)
      [release, "default"].each do |version|
        bootloader_path = File.join(path, 'bootloader-universe/pxegrub2', os, version, arch)

        logger.debug "TFTP: Checking if bootloader universe is configured for OS '#{os}' version '#{version}' (#{arch})."

        if Dir.exist?(bootloader_path)
          logger.debug "TFTP: Directory '#{bootloader_path}' exists."
          return bootloader_path
        end

        logger.debug "TFTP: Directory '#{bootloader_path}' does not exist."
      end
      nil
    end

    def bootloader_universe_symlinks(bootloader_path, pxeconfig_dir_mac)
      Dir.glob(File.join(bootloader_path, '*.efi')).map do |source_file|
        { source: source_file, symlink: File.join(pxeconfig_dir_mac, File.basename(source_file)) }
      end
    end

    def default_symlinks(bootfile_suffix, pxeconfig_dir_mac)
      pxeconfig_dir = pxeconfig_dir()

      grub_source = "grub#{bootfile_suffix}.efi"
      shim_source = "shim#{bootfile_suffix}.efi"

      [
        { source: grub_source, symlink: "boot.efi" },
        { source: grub_source, symlink: grub_source },
        { source: shim_source, symlink: "boot-sb.efi" },
        { source: shim_source, symlink: shim_source },
      ].map do |link|
        { source: File.join(pxeconfig_dir, link[:source]), symlink: File.join(pxeconfig_dir_mac, link[:symlink]) }
      end
    end

    def create_symlinks(symlinks)
      symlinks.each do |link|
        relative_source_path = Pathname.new(link[:source]).relative_path_from(Pathname.new(link[:symlink]).parent).to_s

        logger.debug "TFTP: Creating relative symlink: #{link[:symlink]} -> #{relative_source_path}"
        FileUtils.ln_s(relative_source_path, link[:symlink], force: true)
      end
    end

    # Configures bootloader files for a host in its host-config directory
    #
    # @param mac [String] The MAC address of the host
    # @param os [String] The lowercase name of the operating system of the host
    # @param release [String] The major and minor version of the operating system of the host
    # @param arch [String] The architecture of the operating system of the host
    # @param bootfile_suffix [String] The architecture specific boot filename suffix
    def setup_bootloader(mac:, os:, release:, arch:, bootfile_suffix:)
      pxeconfig_dir_mac = pxeconfig_dir(mac)

      logger.debug "TFTP: Deploying host specific bootloader files to '#{pxeconfig_dir_mac}'."

      FileUtils.mkdir_p(pxeconfig_dir_mac)
      FileUtils.rm_f(Dir.glob("#{pxeconfig_dir_mac}/*.efi"))

      bootloader_path = bootloader_path(os, release, arch)

      if bootloader_path
        logger.debug "TFTP: Creating symlinks from bootloader universe."
        symlinks = bootloader_universe_symlinks(bootloader_path, pxeconfig_dir_mac)
      else
        logger.debug "TFTP: Creating symlinks from default bootloader files."
        symlinks = default_symlinks(bootfile_suffix, pxeconfig_dir_mac)
      end
      create_symlinks(symlinks)
    end

    def del(mac)
      super mac
      delete_host_dir mac
    end

    def pxeconfig_dir(mac = nil)
      if mac
        File.join(path, 'host-config', dashed_mac(mac).downcase, 'grub2')
      else
        File.join(path, 'grub2')
      end
    end

    def pxe_default
      ["#{pxeconfig_dir}/grub.cfg"]
    end

    def pxeconfig_file(mac)
      pxeconfig_dir_mac = pxeconfig_dir(mac)
      [
        "#{pxeconfig_dir_mac}/grub.cfg",
        "#{pxeconfig_dir_mac}/grub.cfg-01-#{dashed_mac(mac).downcase}",
        "#{pxeconfig_dir_mac}/grub.cfg-#{mac.downcase}",
        "#{pxeconfig_dir}/grub.cfg-01-" + dashed_mac(mac).downcase,
        "#{pxeconfig_dir}/grub.cfg-#{mac.downcase}",
      ]
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
      ["#{pxeconfig_dir}/01-" + dashed_mac(mac).downcase + ".ipxe"]
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
