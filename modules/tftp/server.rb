require 'fileutils'
require 'pathname'
require 'digest'
require 'tempfile'
require 'proxy/file_lock'
require 'tftp/dir_lock'
require 'tftp/extractor_tgz'
require 'tftp/extractor_iso'

module Proxy::TFTP
  extend Proxy::Log

  DIR_LOCK = DirLock.new

  def self.ensure_no_extraction!(directory)
    return unless DIR_LOCK.active?(directory)

    raise BootFilesInProgress, "Bootloader universe files are currently being downloaded or extracted: #{directory}"
  end

  def self.bootloader_universe_directories(os:, release:, arch:)
    parts = [os, release, arch].map(&:to_s)
    unless parts.all? { |part| !%w[. ..].include?(part) && /\A[a-z0-9_.-]+\z/i.match?(part) }
      raise 'Invalid bootloader universe operating system path'
    end

    ensure_tftp_root
    [release, 'default'].uniq.map do |version|
      tftp_path(File.join('bootloader-universe', 'pxegrub2', os, version, arch)).to_s
    end
  end

  def self.try_lock_host_config(mac)
    ensure_tftp_root
    lock_path = tftp_path(File.join('host-config', ".#{mac.tr(':', '-').downcase}.lock"), reject_final_symlink: false)
    ensure_tftp_file_path(lock_path)
    Proxy::FileLock.try_locking(lock_path)
  end

  def self.validate_universe_boot_files!(os:, release:, arch:, archive:, kernel:, initrd:, source_digest:)
    parts = [os, release, arch].map(&:to_s)
    unless parts.all? { |part| !%w[. ..].include?(part) && /\A[a-z0-9_.-]+\z/i.match?(part) }
      raise 'Invalid bootloader universe operating system path'
    end
    raise 'Invalid bootloader universe source digest' unless /\A[0-9a-f]{64}\z/.match?(source_digest.to_s)

    directory = File.join('bootloader-universe', 'pxegrub2', *parts)
    boot_files = { archive: archive, kernel: kernel, initrd: initrd }.transform_values do |path|
      relative = validate_tftp_relative_path(path)
      raise 'Boot files must belong to the selected bootloader universe directory' unless relative.dirname.to_s == directory

      tftp_path(relative)
    end

    grub = tftp_path("#{directory}/grubx64.efi")
    shim = tftp_path("#{directory}/shimx64.efi")
    links = { 'boot.efi' => grub, 'boot-sb.efi' => shim }
    links_ready = links.all? do |name, target|
      link = tftp_path("#{directory}/#{name}", reject_final_symlink: false)
      File.symlink?(link) && File.realpath(link) == target.to_s
    rescue Errno::ENOENT
      false
    end
    source_marker = tftp_path("#{archive}.source")
    files_ready = (boot_files.values + [source_marker, grub, shim]).all? { |path| File.file?(path) }
    unless files_ready && links_ready && File.read(source_marker).strip == source_digest
      raise "Bootloader universe boot files are missing or do not match the selected source: #{directory}. " \
        "Download boot files for Operating System '#{os} #{release}'"
    end

    true
  end

  class Server
    include Proxy::Log
    # Creates TFTP pxeconfig file
    def set(mac, config)
      raise "Invalid parameters received" if mac.nil? || config.nil?
      pxeconfig_file(mac).each do |file|
        write_file file, config
      end

      host_pxe_dir = File.join(path, 'host-config', dashed_mac(mac).downcase, host_pxe_dir_name)
      Proxy::TFTP.ensure_tftp_path(host_pxe_dir, create_parents: true, reject_final_symlink: true)

      host_pxeconfig_files(mac).each do |path|
        ln_from = File.join(host_pxe_dir, path.split('/').last)
        Proxy::TFTP.create_relative_symlink(ln_from, path, logger)
      end

      true
    end

    # Removes pxeconfig files
    def del(mac)
      pxeconfig_file(mac).each do |file|
        delete_file file
      end

      delete_host_dir mac

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
      Proxy::TFTP.ensure_tftp_path(file, reject_final_symlink: true)
      raise("File #{file} not found") unless File.exist?(file)
      File.open(file, 'r', &:readlines)
    end

    def write_file(file, contents)
      target = Proxy::TFTP.ensure_tftp_file_path(file)
      mode = File.file?(target) ? File.stat(target).mode & 0o777 : 0o666 & ~File.umask
      temporary = Tempfile.new([".#{target.basename}.", '.tmp'], target.dirname.to_s)
      begin
        temporary.chmod(mode)
        temporary.write(contents)
        temporary.flush
        File.rename(temporary.path, target.to_s)
      ensure
        temporary.close!
      end
      logger.debug "TFTP: #{file} created successfully"
    end

    def delete_file(file)
      if File.exist?(file) || File.symlink?(file)
        Proxy::TFTP.ensure_tftp_path(file)
        FileUtils.rm_f file
        logger.debug "TFTP: #{file} removed successfully"
      else
        logger.debug "TFTP: Skipping a request to delete a file which doesn't exists"
      end
    end

    def delete_host_dir(mac)
      host_dir = File.join(path, 'host-config', dashed_mac(mac).downcase)
      return unless Dir.exist?(host_dir)

      Proxy::TFTP.ensure_tftp_path(host_dir, reject_final_symlink: true)
      logger.debug "TFTP: Removing directory '#{host_dir}'."
      FileUtils.rm_rf host_dir
    end

    def setup_bootloader(mac:, os:, release:, arch:, bootfile_suffix:, use_universe: false)
    end

    def dashed_mac(mac)
      mac.tr(':', '-')
    end

    def host_pxeconfig_files(mac)
      pxeconfig_file(mac)
    end
  end

  class Syslinux < Server
    def pxeconfig_dir
      File.join(path, 'pxelinux.cfg')
    end

    def pxe_default
      ["#{pxeconfig_dir}/default"]
    end

    def pxeconfig_file(mac)
      ["#{pxeconfig_dir}/01-" + dashed_mac(mac).downcase]
    end

    def host_pxe_dir_name
      'pxe'
    end
  end
  class Pxelinux < Syslinux; end
  class Pxegrub2 < Server
    UNIVERSE_BOOT_FILE_NAMES = %w[linux initrd.gz vmlinuz initrd.img].freeze

    def set(mac, config)
      super
      # Some builds use the directory of the EFI image as their prefix.
      Proxy::TFTP.create_relative_symlink(File.join(pxeconfig_dir(mac), 'grub.cfg'), pxeconfig_file(mac).first, logger)
      true
    end

    def bootloader_path(os, release, arch)
      Proxy::TFTP.ensure_tftp_root
      [release, "default"].each do |version|
        bootloader_path = Proxy::TFTP.tftp_path(File.join('bootloader-universe', 'pxegrub2', os, version, arch)).to_s
        Proxy::TFTP.ensure_no_extraction!(bootloader_path)

        logger.debug "TFTP: Checking if bootloader universe is configured for OS '#{os}' version '#{version}' (#{arch})."

        if Proxy::TFTP.tftp_directory?(bootloader_path)
          logger.debug "TFTP: Directory '#{bootloader_path}' exists."
          return bootloader_path
        end

        logger.debug "TFTP: Directory '#{bootloader_path}' does not exist."
      end
      nil
    end

    def bootloader_universe_symlinks(bootloader_path, pxeconfig_dir_mac)
      files = Dir.glob(File.join(bootloader_path, '*.efi'))
      files.concat(UNIVERSE_BOOT_FILE_NAMES.filter_map do |name|
        path = File.join(bootloader_path, name)
        path if File.file?(path)
      end)
      files.map do |source_file|
        # Resolve universe aliases so create_relative_symlink can validate the
        # real file against the TFTP root before making the host-specific link.
        { source: File.realpath(source_file), symlink: File.join(pxeconfig_dir_mac, File.basename(source_file)) }
      end
    end

    def default_symlinks(bootfile_suffix, pxeconfig_dir_mac)
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
        Proxy::TFTP.create_relative_symlink(link[:symlink], link[:source], logger)
      end
    end

    # Configures bootloader files for a host in its host-config directory
    #
    # @param mac [String] The MAC address of the host
    # @param os [String] The lowercase name of the operating system of the host
    # @param release [String] The major and minor version of the operating system of the host
    # @param arch [String] The architecture of the operating system of the host
    # @param bootfile_suffix [String] The architecture specific boot filename suffix
    def setup_bootloader(mac:, os:, release:, arch:, bootfile_suffix:, use_universe: false)
      pxeconfig_dir_mac = pxeconfig_dir(mac)

      logger.debug "TFTP: Deploying host specific bootloader files to '#{pxeconfig_dir_mac}'."

      bootloader_path = use_universe ? bootloader_path(os, release, arch) : nil

      Proxy::TFTP.ensure_tftp_path(pxeconfig_dir_mac, create_parents: true, reject_final_symlink: true)
      managed_files = Dir.glob("#{pxeconfig_dir_mac}/*.efi")
      managed_files.concat(UNIVERSE_BOOT_FILE_NAMES.map { |name| File.join(pxeconfig_dir_mac, name) })
      FileUtils.rm_f(managed_files)

      if bootloader_path
        logger.debug "TFTP: Creating symlinks from bootloader universe."
        symlinks = bootloader_universe_symlinks(bootloader_path, pxeconfig_dir_mac)
      else
        logger.debug "TFTP: Creating symlinks from default bootloader files."
        symlinks = default_symlinks(bootfile_suffix, pxeconfig_dir_mac)
      end
      create_symlinks(symlinks)
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
      [
        "#{pxeconfig_dir}/grub.cfg-01-" + dashed_mac(mac).downcase,
        "#{pxeconfig_dir}/grub.cfg-#{mac.downcase}",
      ]
    end

    def host_pxeconfig_files(_mac)
      []
    end

    def host_pxe_dir_name
      'grub2'
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

    def host_pxe_dir_name
      'ztp'
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

    def host_pxe_dir_name
      'poap'
    end
  end

  class Ipxe < Server
    def pxeconfig_dir
      File.join(path, 'pxelinux.cfg')
    end

    def pxe_default
      ["#{pxeconfig_dir}/default.ipxe"]
    end

    def pxeconfig_file(mac)
      file = "01-" + dashed_mac(mac).downcase + ".ipxe"
      [File.join(pxeconfig_dir, file)]
    end

    def host_pxe_dir_name
      'ipxe'
    end
  end

  EXTRACTORS = {
    'tgz' => Proxy::TFTP::Extractor::Tgz,
    'iso' => Proxy::TFTP::Extractor::Iso,
  }.freeze

  def self.fetch_boot_file(destination, source, extract = nil, exact_destination: false)
    return extract_boot_files(extract) if extract

    if exact_destination && destination.to_s.end_with?('/')
      raise "TFTP destination must be a file path: #{destination}"
    end
    ensure_tftp_root
    filename    = exact_destination ? destination : boot_filename(destination, source)
    destination = tftp_path(filename)

    # Ensure that our image directory exists
    # as the destination might contain another sub directory
    ensure_tftp_file_path(destination)
    if exact_destination && File.directory?(destination)
      raise "TFTP destination must be a file path: #{destination}"
    end
    track_download(source, destination, conditional: !exact_destination)
  end

  def self.track_download(source, destination, conditional: true)
    destinations = [destination.to_s]
    DIR_LOCK.with_write(destinations) do |release, defer_release|
      download = choose_protocol_and_fetch(source, destination, conditional: conditional, &release)
      raise BootFilesInProgress, "TFTP file is already being downloaded: #{destination}" if download == false

      defer_release.call if download.respond_to?(:join)
      download
    end
  end

  def self.extract_boot_files(options)
    options = prepare_extract_options(options)
    paths = [options[:archive], "#{options[:archive]}.source", *options[:files].values, *options[:symlinks].keys]
    DIR_LOCK.with_write(paths) do |release, defer_release|
      # Create output directories before returning, so host-config setup can
      # find the in-memory extraction state while the worker is downloading.
      options[:files].each_value { |path| ensure_tftp_file_path(path) }
      # A previous extraction may have created these links. Keep validating
      # their parents, but allow the final link so it can be replaced.
      options[:symlinks].each_key { |path| ensure_tftp_path(path, create_parents: true) }
      logger.info "TFTP: Queuing boot file extraction from #{options[:source]} to #{options[:archive]}"
      # Keep the API asynchronous. The worker owns download completion and all
      # extraction errors are logged there because the request has already ended.
      worker = Thread.new { perform_extract_boot_files(options, release) }
      defer_release.call
      worker
    end
  end

  def self.prepare_extract_options(options)
    options = symbolize_keys(options)
    type = options[:type].to_s
    extractor = EXTRACTORS[type]
    raise "Cannot extract boot file, unknown archive type: #{type}" unless extractor

    source = required_option(options, :source)
    archive_path = required_option(options, :destination)
    validate_tftp_relative_path(archive_path)
    ensure_tftp_root
    archive = tftp_path(archive_path)
    files = options[:files] || {}
    symlinks = options[:symlinks] || {}
    raise 'Cannot extract boot file, files must be a map' unless files.is_a?(Hash)
    raise 'Cannot extract boot file, symlinks must be a map' unless symlinks.is_a?(Hash)

    {
      source: source.to_s,
      archive: archive,
      extractor: extractor,
      files: files.each_with_object({}) { |(destination, member), result| result[archive_member_path(member)] = tftp_path(destination) },
      symlinks: symlinks.each_with_object({}) { |(link, target), result| result[tftp_path(link, reject_final_symlink: false)] = tftp_path(target) },
    }
  end

  def self.perform_extract_boot_files(options, release)
    lock = nil
    lock_path = File.join(File.dirname(options[:archive]), ".#{File.basename(options[:archive])}.extract.lock")
    begin
      ensure_tftp_file_path(options[:archive])
      ensure_tftp_file_path(lock_path)
      lock = Proxy::FileLock.try_locking(lock_path)
      unless lock
        logger.info "TFTP: Skipping boot file extraction because it is already running for #{options[:archive]}"
        return
      end

      old_state = file_state(options[:archive])
      source_marker = "#{options[:archive]}.source"
      ensure_tftp_file_path(source_marker)
      source_digest = Digest::SHA256.hexdigest(options[:source])
      source_changed = !File.file?(source_marker) || File.read(source_marker).strip != source_digest
      logger.info "TFTP: Downloading boot archive #{options[:source]}"
      download = ::Proxy::HttpDownload.new(options[:source], options[:archive].to_s,
                                           connect_timeout: Proxy::TFTP::Plugin.settings.tftp_connect_timeout,
                                           max_time: Proxy::TFTP::Plugin.settings.tftp_download_max_time,
                                           verify_server_cert: Proxy::TFTP::Plugin.settings.verify_server_cert,
                                           preflight: Proxy::TFTP::Plugin.settings.tftp_http_download_preflight,
                                           conditional: !source_changed).start
      unless download
        logger.warn "TFTP: Skipping boot file extraction because the archive download is already in progress"
        return
      end

      status = download.join
      unless status.zero?
        logger.error "TFTP: Boot archive download failed with exit status #{status}: #{options[:source]}"
        return
      end

      ensure_tftp_file_path(options[:archive])
      unless source_changed || old_state != file_state(options[:archive]) || files_missing?(options)
        logger.info "TFTP: Boot archive is unchanged and all files exist; skipping extraction: #{options[:archive]}"
        return
      end

      logger.info "TFTP: Extracting updated boot archive #{options[:archive]}"
      logger.debug "TFTP: Extracting files #{options[:files].keys.join(', ')}"
      # Extraction may replace only some files before failing. An old source
      # marker must never certify that partially replaced set as bootable.
      FileUtils.rm_f(source_marker)
      options[:extractor].extract(options[:archive], options[:files], options[:symlinks])
      File.write(source_marker, source_digest)
      logger.info "TFTP: Boot archive extraction completed: #{options[:archive]}"
    rescue StandardError => e
      logger.error "TFTP: Boot archive extraction failed: #{options[:archive]}", e
      logger.debug e.backtrace.join("\n") if e.backtrace
    ensure
      begin
        Proxy::FileLock.unlock(lock) if lock
      ensure
        release.call
      end
    end
  end

  def self.files_missing?(options)
    options[:files].each_value do |destination|
      return true unless File.exist?(destination)
    end
    options[:symlinks].each_key do |link|
      return true unless File.symlink?(link) || File.exist?(link)
    end
    false
  end

  def self.tftp_path(path, reject_final_symlink: true)
    pathname = validate_tftp_relative_path(path)

    root = tftp_root
    resolved = root.join(pathname).cleanpath
    raise "TFTP path outside of tftproot: #{path}" unless resolved == root || resolved.to_s.start_with?("#{root}/")

    ensure_tftp_existing_path(resolved, reject_final_symlink: reject_final_symlink)
    resolved
  end

  def self.validate_tftp_relative_path(path)
    value = path.to_s
    pathname = Pathname.new(value)
    raise "TFTP path must be relative: #{value}" if value.empty? || pathname.absolute? || pathname.each_filename.include?('..')
    pathname
  end

  def self.configured_tftp_root
    configured_path = Pathname.new(Proxy::TFTP::Plugin.settings.tftproot)
    return configured_path.cleanpath if configured_path.absolute?

    Pathname.new(__dir__).join(configured_path).cleanpath
  end

  def self.tftp_root
    Pathname.new(File.realpath(configured_tftp_root)).cleanpath
  rescue Errno::ENOENT
    raise "TFTP root does not exist: #{configured_tftp_root}"
  end

  # Verify the physical parents of a path before using it.  Lexical checks are
  # insufficient because a symlink below the chroot can redirect an otherwise
  # valid path outside it.
  def self.ensure_tftp_path(path, create_parents: false, reject_final_symlink: false)
    pathname = Pathname.new(path).expand_path.cleanpath
    ensure_tftp_root if create_parents
    root = tftp_root
    raise "TFTP path outside of tftproot: #{path}" unless pathname == root || pathname.to_s.start_with?("#{root}/")

    current = root
    relative_parts = pathname.relative_path_from(root).each_filename.to_a
    relative_parts.each_with_index do |part, index|
      current = current.join(part)
      final = index == relative_parts.length - 1
      begin
        stat = File.lstat(current)
        raise "TFTP path contains a symlink: #{current}" if stat.symlink? && (!final || reject_final_symlink)
        raise "TFTP path component is not a directory: #{current}" if !final && !stat.directory?
      rescue Errno::ENOENT
        if !final && create_parents
          create_tftp_directory(current)
        elsif !final
          raise "TFTP parent directory does not exist: #{current}"
        end
      end
    end
    pathname
  end

  def self.ensure_tftp_file_path(path)
    ensure_tftp_path(path, create_parents: true, reject_final_symlink: true)
  end

  def self.create_tftp_directory(path)
    Dir.mkdir(path)
  rescue Errno::EEXIST
    stat = File.lstat(path)
    raise "TFTP path contains a symlink: #{path}" if stat.symlink?
    raise "TFTP path component is not a directory: #{path}" unless stat.directory?
  end

  def self.ensure_tftp_root
    configured_root = configured_tftp_root
    FileUtils.mkdir_p configured_root.to_s unless File.exist?(configured_root)
    tftp_root
  end

  # This is used while validating request parameters.  It walks only the
  # existing portion, so callers may still request new directories and files.
  def self.ensure_tftp_existing_path(path, reject_final_symlink: true)
    pathname = Pathname.new(path).expand_path.cleanpath
    root = tftp_root
    raise "TFTP path outside of tftproot: #{path}" unless pathname == root || pathname.to_s.start_with?("#{root}/")

    current = root
    parts = pathname.relative_path_from(root).each_filename.to_a
    parts.each_with_index do |part, index|
      current = current.join(part)
      begin
        stat = File.lstat(current)
      rescue Errno::ENOENT
        break
      end
      final = index == parts.length - 1
      raise "TFTP path contains a symlink: #{current}" if stat.symlink? && (!final || reject_final_symlink)
      raise "TFTP path component is not a directory: #{current}" unless current == pathname || stat.directory?
    end
  end

  def self.tftp_directory?(path)
    return false unless Dir.exist?(path)

    ensure_tftp_path(path, reject_final_symlink: true)
    true
  end

  def self.create_relative_symlink(link, target, log = logger)
    link = ensure_tftp_path(link, create_parents: true)
    target = Pathname.new(target).expand_path.cleanpath
    ensure_tftp_existing_path(target)
    relative_target = target.relative_path_from(link.dirname).to_s
    log.debug "TFTP: Creating relative symlink: #{link} -> #{relative_target}"
    FileUtils.ln_s relative_target, link.to_s, force: true
  end

  def self.archive_member_path(path)
    value = path.to_s
    pathname = Pathname.new(value)
    raise "Archive path must be relative: #{value}" if value.empty? || pathname.absolute? || pathname.each_filename.include?('..')

    pathname.cleanpath.to_s
  end

  def self.file_state(path)
    return nil unless path.file?
    stat = path.stat
    [stat.size, stat.mtime]
  end

  def self.required_option(options, name)
    value = options[name]
    raise "Cannot extract boot file, missing #{name}" if value.nil? || value.to_s.empty?
    value
  end

  def self.symbolize_keys(options)
    return options unless options.is_a?(Hash)
    options.each_with_object({}) { |(key, value), result| result[key.to_sym] = value }
  end

  def self.choose_protocol_and_fetch(src, destination, conditional: true, &block)
    case URI(src).scheme
    when 'http', 'https', 'ftp'
      ::Proxy::HttpDownload.new(src.to_s, destination.to_s,
                                connect_timeout: Proxy::TFTP::Plugin.settings.tftp_connect_timeout,
                                max_time: Proxy::TFTP::Plugin.settings.tftp_download_max_time,
                                verify_server_cert: Proxy::TFTP::Plugin.settings.verify_server_cert,
                                preflight: Proxy::TFTP::Plugin.settings.tftp_http_download_preflight,
                                conditional: conditional).start(&block)

    when 'nfs'
      logger.debug "TFTP: NFS as a protocol for installation medium detected."
    else
      raise "Cannot fetch boot file, unknown protocol for medium source path: #{src}"
    end
  end

  def self.boot_filename(dst, src)
    # Do not append a '-' if the dst is a directory path
    dst.end_with?('/') ? dst + src.split("/")[-1] : dst + '-' + src.split("/")[-1]
  end
end
