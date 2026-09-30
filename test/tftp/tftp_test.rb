require 'test_helper'
require 'tftp/tftp_plugin'
require "tftp/server"
require 'rubygems/package'
require 'rubygems/package/tar_writer'
require 'zlib'

class TftpTest < Test::Unit::TestCase
  def setup
    @tftp = Proxy::TFTP::Server.new
    Proxy::TFTP::Plugin.load_test_settings(:tftproot => "/some/root")
  end

  def test_should_have_a_logger
    assert_respond_to @tftp, :logger
  end

  def test_path_to_tftp_directory_without_tftproot_setting
    Proxy::TFTP::Plugin.load_test_settings()
    assert_equal "/var/lib/tftpboot", @tftp.send(:path)
  end

  def test_path_to_tftp_directory_with_tftproot_setting
    assert_equal "/some/root", @tftp.send(:path)
  end

  def test_path_to_tftp_directory_with_relative_tftproot_setting
    Proxy::TFTP::Plugin.load_test_settings(:tftproot => "./some/root")
    assert_equal Pathname.new(__dir__).join("..", "..", "modules", "tftp", "some", "root").to_s, @tftp.send(:path)
  end

  def test_paths_inside_tftp_directory_dont_raise_errors
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    ::Proxy::HttpDownload.any_instance.stubs(:start).returns(true)
    stub_request(:head, 'http://localhost/file').to_return(status: 200)

    assert Proxy::TFTP.send(:fetch_boot_file, 'boot/file', 'http://localhost/file')
  ensure
    FileUtils.rm_rf root if root
  end

  def test_fetch_boot_file_creates_missing_tftp_root
    parent = Dir.mktmpdir
    root = File.join(parent, 'tftp')
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    ::Proxy::HttpDownload.any_instance.stubs(:start).returns(true)
    stub_request(:head, 'http://localhost/file').to_return(status: 200)

    assert Proxy::TFTP.send(:fetch_boot_file, 'boot/file', 'http://localhost/file')
    assert File.directory?(root)
  ensure
    FileUtils.rm_rf parent if parent
  end

  def test_fetch_boot_file_rejects_a_download_when_its_directory_is_busy
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    Proxy::TFTP.expects(:choose_protocol_and_fetch).never
    directory = File.join(root, 'boot')
    Proxy::TFTP::DIR_LOCK.with_write([directory]) do
      error = assert_raises(Proxy::TFTP::BootFilesInProgress) do
        Proxy::TFTP.fetch_boot_file('boot/file', 'http://localhost/file')
      end
      assert_equal 409, error.status_code
    end
  ensure
    FileUtils.rm_rf(root) if root
  end

  def test_paths_outside_tftp_directory_raise_errors
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    ::Proxy::HttpDownload.any_instance.stubs(:start).returns(true)

    assert_raises RuntimeError do
      Proxy::TFTP.send(:fetch_boot_file, '../outside/boot/file', 'http://localhost/file')
    end
  ensure
    FileUtils.rm_rf root if root
  end

  def test_boot_filename_has_no_dash_when_prefix_ends_with_slash
    assert_equal "a/b/c/somefile", Proxy::TFTP.boot_filename('a/b/c/', '/d/somefile')
  end

  def test_boot_filename_uses_dash_when_prefix_does_not_end_with_slash
    assert_equal "a/b/c-somefile", Proxy::TFTP.boot_filename('a/b/c', '/d/somefile')
  end

  def test_fetch_boot_file_can_use_exact_destination
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    Proxy::TFTP.expects(:choose_protocol_and_fetch).with(
      'http://localhost/file',
      Pathname.new(File.join(root, 'bootloader-universe/pxegrub2/ubuntu/26.04/amd64/boot.iso')),
      conditional: false
    ).returns(true)

    Proxy::TFTP.fetch_boot_file(
      'bootloader-universe/pxegrub2/ubuntu/26.04/amd64/boot.iso',
      'http://localhost/file',
      nil,
      exact_destination: true
    )
  ensure
    FileUtils.rm_rf root if root
  end

  def test_universe_boot_files_are_ready_only_for_the_matching_archive_source
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    directory = 'bootloader-universe/pxegrub2/debian/12/x86_64'
    absolute_directory = File.join(root, directory)
    FileUtils.mkdir_p(absolute_directory)
    archive = "#{directory}/netboot.tar.gz"
    kernel = "#{directory}/linux"
    initrd = "#{directory}/initrd.gz"
    [archive, kernel, initrd, "#{directory}/grubx64.efi", "#{directory}/shimx64.efi"].each { |path| File.write(File.join(root, path), 'data') }
    File.symlink('grubx64.efi', File.join(absolute_directory, 'boot.efi'))
    File.symlink('shimx64.efi', File.join(absolute_directory, 'boot-sb.efi'))
    digest = Digest::SHA256.hexdigest('https://example.test/netboot.tar.gz')
    File.write(File.join(root, "#{archive}.source"), digest)
    options = { os: 'debian', release: '12', arch: 'x86_64', archive: archive,
                kernel: kernel, initrd: initrd, source_digest: digest }

    assert Proxy::TFTP.validate_universe_boot_files!(**options)

    # Debian Secure Boot must have both the Shim binary and its DHCP alias.
    shim = File.join(absolute_directory, 'shimx64.efi')
    File.unlink(shim)
    assert_raises(RuntimeError) { Proxy::TFTP.validate_universe_boot_files!(**options) }
    File.write(shim, 'data')
    boot_sb = File.join(absolute_directory, 'boot-sb.efi')
    File.unlink(boot_sb)
    assert_raises(RuntimeError) { Proxy::TFTP.validate_universe_boot_files!(**options) }
    File.symlink('shimx64.efi', boot_sb)

    error = assert_raises(RuntimeError) do
      Proxy::TFTP.validate_universe_boot_files!(**options.merge(source_digest: '0' * 64))
    end
    assert_match(/Download boot files for Operating System 'debian 12'/, error.message)

    File.unlink(File.join(root, initrd))
    error = assert_raises(RuntimeError) { Proxy::TFTP.validate_universe_boot_files!(**options) }
    assert_match(/Download boot files for Operating System 'debian 12'/, error.message)
  ensure
    FileUtils.rm_rf(root) if root
  end

  def test_universe_boot_file_validation_rejects_paths_outside_the_selected_directory
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)

    assert_raises(RuntimeError) do
      Proxy::TFTP.validate_universe_boot_files!(
        os: 'debian', release: '12', arch: 'x86_64',
        archive: 'bootloader-universe/pxegrub2/debian/12/x86_64/netboot.tar.gz',
        kernel: 'bootloader-universe/pxegrub2/debian/13/x86_64/linux',
        initrd: 'bootloader-universe/pxegrub2/debian/12/x86_64/initrd.gz',
        source_digest: '0' * 64
      )
    end
  ensure
    FileUtils.rm_rf(root) if root
  end

  def test_redhat_universe_boot_files_require_shim_and_both_efi_links
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    directory = 'bootloader-universe/pxegrub2/centos/10/x86_64'
    absolute_directory = File.join(root, directory)
    FileUtils.mkdir_p(absolute_directory)
    archive = "#{directory}/boot.iso"
    kernel = "#{directory}/vmlinuz"
    initrd = "#{directory}/initrd.img"
    [archive, kernel, initrd, "#{directory}/grubx64.efi", "#{directory}/shimx64.efi"].each do |path|
      File.write(File.join(root, path), 'data')
    end
    File.symlink('grubx64.efi', File.join(absolute_directory, 'boot.efi'))
    File.symlink('shimx64.efi', File.join(absolute_directory, 'boot-sb.efi'))
    digest = Digest::SHA256.hexdigest('https://example.test/boot.iso')
    File.write(File.join(root, "#{archive}.source"), digest)
    options = { os: 'centos', release: '10', arch: 'x86_64', archive: archive,
                kernel: kernel, initrd: initrd, source_digest: digest }

    assert Proxy::TFTP.validate_universe_boot_files!(**options)

    File.unlink(File.join(absolute_directory, 'boot-sb.efi'))
    assert_raises(RuntimeError) { Proxy::TFTP.validate_universe_boot_files!(**options) }
  ensure
    FileUtils.rm_rf(root) if root
  end

  def test_missing_universe_directory_reports_the_operating_system_download_action
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    directory = 'bootloader-universe/pxegrub2/centos/10/x86_64'

    error = assert_raises(RuntimeError) do
      Proxy::TFTP.validate_universe_boot_files!(
        os: 'centos', release: '10', arch: 'x86_64',
        archive: "#{directory}/boot.iso", kernel: "#{directory}/vmlinuz",
        initrd: "#{directory}/initrd.img", source_digest: 'a' * 64
      )
    end
    assert_match(/Download boot files for Operating System 'centos 10'/, error.message)
  ensure
    FileUtils.rm_rf(root) if root
  end

  def test_fetch_boot_file_rejects_directory_destination
    assert_raises RuntimeError do
      Proxy::TFTP.fetch_boot_file('bootloader-universe/ubuntu/', 'http://localhost/file', nil, exact_destination: true)
    end
  end

  def test_choose_protocol_and_fetch_wget
    ::Proxy::HttpDownload.any_instance.expects(:start).returns(true).times(3)
    stub_request(:head, 'http://proxy.test/').to_return(status: 200)
    stub_request(:head, 'https://proxy.test/').to_return(status: 200)
    %w(http://proxy.test https://proxy.test ftp://proxy.test).each do |src|
      Proxy::TFTP.choose_protocol_and_fetch src, '/destination'
    end
  end

  def test_choose_protocol_and_fetch_wget_with_timeout
    src = "https://proxy.test"
    dst = "/destination"
    tftp_connect_timeout = "40"
    verify_server_cert = false
    Proxy::TFTP::Plugin.load_test_settings(
      :tftp_connect_timeout => tftp_connect_timeout,
      :verify_server_cert => verify_server_cert,
      :tftp_http_download_preflight => true
    )

    ::Proxy::HttpDownload.expects(:new).returns(stub('tftp', :start => true)).
      with(src, dst, connect_timeout: tftp_connect_timeout, verify_server_cert: verify_server_cert,
           max_time: 3600, preflight: true, conditional: true)

    Proxy::TFTP.choose_protocol_and_fetch src, dst
  end

  def test_choose_protocol_and_fetch_nfs
    assert_nothing_raised RuntimeError do
      Proxy::TFTP.choose_protocol_and_fetch 'nfs://proxy.test', '/destination'
    end
  end

  def test_choose_protocol_and_fetch_unknown
    assert_raises RuntimeError do
      Proxy::TFTP.choose_protocol_and_fetch 'git://proxy.test', '/destination'
    end
  end

  def test_extract_tgz_files_and_create_relative_symlinks
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    source_archive = File.join(root, 'source.tgz')
    archive = File.join(root, 'archives', 'debian.tgz')
    create_tgz source_archive, 'boot/grub/grubx64.efi' => 'grub', 'boot/grub/shimx64.efi' => 'shim'
    download = Object.new
    download.define_singleton_method(:start) { self }
    download.define_singleton_method(:join) do
      FileUtils.cp source_archive, archive
      0
    end
    Proxy::HttpDownload.expects(:new).returns(download)

    worker = Proxy::TFTP.extract_boot_files(
      source: 'https://example.test/debian.tgz',
      destination: 'archives/debian.tgz',
      type: 'tgz',
      files: {
        'bootloader-universe/debian/grubx64.efi' => 'boot/grub/grubx64.efi',
        'bootloader-universe/debian/shimx64.efi' => 'boot/grub/shimx64.efi',
      },
      symlinks: {
        'bootloader-universe/debian/boot.efi' => 'bootloader-universe/debian/grubx64.efi',
      }
    )
    worker.join

    assert_equal 'grub', File.read(File.join(root, 'bootloader-universe/debian/grubx64.efi'))
    assert_equal 'shim', File.read(File.join(root, 'bootloader-universe/debian/shimx64.efi'))
    assert_equal 'grubx64.efi', File.readlink(File.join(root, 'bootloader-universe/debian/boot.efi'))
    lock_path = File.join(File.dirname(archive), ".#{File.basename(archive)}.extract.lock")
    lock = Proxy::FileLock.try_locking(lock_path)
    assert_not_nil lock
    Proxy::FileLock.unlock(lock)
  ensure
    FileUtils.rm_rf root if root
  end

  def test_extract_tgz_can_be_requested_again_after_creating_symlinks
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    source_archive = File.join(root, 'source.tgz')
    archive = File.join(root, 'archives', 'debian.tgz')
    create_tgz source_archive, 'boot/grub/grubx64.efi' => 'grub'
    download = Object.new
    download.define_singleton_method(:start) { self }
    download.define_singleton_method(:join) do
      FileUtils.cp source_archive, archive
      0
    end
    Proxy::HttpDownload.expects(:new).twice.returns(download)
    request = {
      source: 'https://example.test/debian.tgz',
      destination: 'archives/debian.tgz',
      type: 'tgz',
      files: {
        'bootloader-universe/debian/grubx64.efi' => 'boot/grub/grubx64.efi',
      },
      symlinks: {
        'bootloader-universe/debian/boot.efi' => 'bootloader-universe/debian/grubx64.efi',
      },
    }

    2.times { Proxy::TFTP.extract_boot_files(request).join }

    assert_equal 'grub', File.read(File.join(root, 'bootloader-universe/debian/grubx64.efi'))
    assert_equal 'grubx64.efi', File.readlink(File.join(root, 'bootloader-universe/debian/boot.efi'))
  ensure
    FileUtils.rm_rf root if root
  end

  def test_extract_still_rejects_a_symlinked_parent_of_a_link
    root = Dir.mktmpdir
    outside = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    FileUtils.mkdir_p File.join(root, 'bootloader-universe')
    FileUtils.ln_s outside, File.join(root, 'bootloader-universe', 'escape')

    assert_raises(RuntimeError) do
      Proxy::TFTP.extract_boot_files(
        source: 'https://example.test/debian.tgz',
        destination: 'debian.tgz',
        type: 'tgz',
        files: {},
        symlinks: { 'bootloader-universe/escape/boot.efi' => 'bootloader-universe/grubx64.efi' }
      )
    end
  ensure
    FileUtils.rm_rf root if root
    FileUtils.rm_rf outside if outside
  end

  def test_extract_tgz_skips_extraction_when_archive_is_unchanged
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    archive = File.join(root, 'debian.tgz')
    create_tgz archive, 'boot/grub/grubx64.efi' => 'grub'
    File.write("#{archive}.source", Digest::SHA256.hexdigest('https://example.test/debian.tgz'))
    Proxy::HttpDownload.expects(:new).returns(stub('download', :start => stub('started_download', :join => 0)))

    # Pre-create the destination file so it is not missing
    dest = File.join(root, 'bootloader-universe/debian/grubx64.efi')
    FileUtils.mkdir_p File.dirname(dest)
    File.write(dest, 'old_content')

    worker = Proxy::TFTP.extract_boot_files(
      source: 'https://example.test/debian.tgz',
      destination: 'debian.tgz',
      type: 'tgz',
      files: { 'bootloader-universe/debian/grubx64.efi' => 'boot/grub/grubx64.efi' }
    )
    worker.join
    assert_equal 'old_content', File.read(dest)
  ensure
    FileUtils.rm_rf root if root
  end

  def test_extract_tgz_refreshes_archive_when_source_url_changes
    root = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    archive = File.join(root, 'debian.tgz')
    create_tgz archive, 'boot/grub/grubx64.efi' => 'old_grub'
    File.write("#{archive}.source", Digest::SHA256.hexdigest('https://old.example.test/debian.tgz'))
    dest = File.join(root, 'bootloader-universe/debian/grubx64.efi')
    FileUtils.mkdir_p File.dirname(dest)
    File.write(dest, 'old_grub')
    replacement = File.join(root, 'replacement.tgz')
    create_tgz replacement, 'boot/grub/grubx64.efi' => 'new_grub'
    download = Object.new
    download.define_singleton_method(:start) { self }
    download.define_singleton_method(:join) do
      FileUtils.cp replacement, archive
      0
    end
    Proxy::HttpDownload.expects(:new).with(
      'https://new.example.test/debian.tgz', archive,
      connect_timeout: 10, max_time: 3600, verify_server_cert: true,
      preflight: true, conditional: false
    ).returns(download)

    worker = Proxy::TFTP.extract_boot_files(
      source: 'https://new.example.test/debian.tgz',
      destination: 'debian.tgz',
      type: 'tgz',
      files: { 'bootloader-universe/debian/grubx64.efi' => 'boot/grub/grubx64.efi' }
    )
    worker.join
    assert_equal 'new_grub', File.read(dest)
    assert_equal Digest::SHA256.hexdigest('https://new.example.test/debian.tgz'), File.read("#{archive}.source")
  ensure
    FileUtils.rm_rf root if root
  end

  def test_extract_rejects_paths_outside_tftp_root
    assert_raises RuntimeError do
      Proxy::TFTP.extract_boot_files(
        source: 'https://example.test/debian.tgz',
        destination: '../debian.tgz',
        type: 'tgz',
        files: {}
      )
    end
  end

  def test_extract_rejects_a_symlinked_parent_directory
    root = Dir.mktmpdir
    outside = Dir.mktmpdir
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    FileUtils.ln_s outside, File.join(root, 'escape')

    error = assert_raises(RuntimeError) do
      Proxy::TFTP.extract_boot_files(
        source: 'https://example.test/debian.tgz',
        destination: 'escape/debian.tgz',
        type: 'tgz',
        files: {}
      )
    end
    assert_match(/contains a symlink/, error.message)
  ensure
    FileUtils.rm_rf root if root
    FileUtils.rm_rf outside if outside
  end

  private

  def create_tgz(path, files)
    FileUtils.mkdir_p File.dirname(path)
    Zlib::GzipWriter.open(path) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        files.each do |name, contents|
          tar.add_file_simple(name, 0o644, contents.bytesize) { |file| file.write(contents) }
        end
      end
    end
  end
end
