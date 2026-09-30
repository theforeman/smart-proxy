require 'test_helper'
require 'tftp/tftp_plugin'
require 'tftp/server'
require 'rubygems/package'
require 'rubygems/package/tar_writer'
require 'zlib'
class TftpFailedExtractionTest < Test::Unit::TestCase
  def test_failed_refresh_from_another_source_removes_source_marker
    check_failed_refresh('https://source-b.test/netboot.tar.gz')
  end

  def test_failed_refresh_from_the_same_source_removes_source_marker
    check_failed_refresh('https://source-a.test/netboot.tar.gz')
  end

  def test_failed_download_from_the_same_source_retries_unconditionally
    root = Dir.mktmpdir('boot-review-')
    Proxy::TFTP::Plugin.load_test_settings(tftproot: root)
    source = 'https://source-a.test/netboot.tar.gz'
    archive = File.join(root, 'netboot.tar.gz')
    marker = "#{archive}.source"
    File.write(archive, 'old archive')
    File.write(marker, Digest::SHA256.hexdigest(source))
    File.write(File.join(root, 'linux'), 'old kernel')
    request = {
      source: source, destination: 'netboot.tar.gz', type: 'tgz',
      files: { 'linux' => 'linux' }
    }
    download_options = {
      connect_timeout: Proxy::TFTP::Plugin.settings.tftp_connect_timeout,
      max_time: Proxy::TFTP::Plugin.settings.tftp_download_max_time,
      verify_server_cert: Proxy::TFTP::Plugin.settings.verify_server_cert,
      preflight: Proxy::TFTP::Plugin.settings.tftp_http_download_preflight,
    }
    failed_download = Object.new
    failed_download.define_singleton_method(:start) { self }
    failed_download.define_singleton_method(:join) do
      File.write(archive, 'partial archive')
      18
    end
    Proxy::HttpDownload.expects(:new).with(source, archive, **download_options, conditional: true).returns(failed_download)

    Proxy::TFTP.extract_boot_files(request).join

    assert_equal 'partial archive', File.read(archive)
    assert !File.exist?(marker)
    assert_equal 'old kernel', File.read(File.join(root, 'linux'))

    Proxy::HttpDownload.expects(:new).with(source, archive, **download_options, conditional: false).
      returns(stub('retry download', start: false))
    Proxy::TFTP.extract_boot_files(request).join
  ensure
    FileUtils.rm_rf(root) if root
  end

  private

  def check_failed_refresh(source)
    root = Dir.mktmpdir('boot-review-')
    Proxy::TFTP::Plugin.load_test_settings(tftproot: root)
    directory = 'bootloader-universe/pxegrub2/debian/12/x86_64'
    absolute = File.join(root, directory)
    FileUtils.mkdir_p(absolute)
    %w[linux initrd.gz grubx64.efi shimx64.efi netboot.tar.gz].each { |name| File.write(File.join(absolute, name), 'source A') }
    digest = Digest::SHA256.hexdigest('https://source-a.test/netboot.tar.gz')
    File.write(File.join(absolute, 'netboot.tar.gz.source'), digest)
    File.symlink('grubx64.efi', File.join(absolute, 'boot.efi'))
    File.symlink('shimx64.efi', File.join(absolute, 'boot-sb.efi'))
    incoming = File.join(root, 'incoming.tgz')
    Zlib::GzipWriter.open(incoming) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        tar.add_file_simple('linux', 0o644, 8) { |file| file.write('source B') }
      end
    end
    archive = File.join(absolute, 'netboot.tar.gz')
    download = Object.new
    download.define_singleton_method(:start) { self }
    download.define_singleton_method(:join) do
      FileUtils.cp(incoming, archive)
      0
    end
    Proxy::HttpDownload.stubs(:new).returns(download)
    request = {
      source: source, destination: "#{directory}/netboot.tar.gz", type: 'tgz',
      files: { "#{directory}/linux" => 'linux', "#{directory}/initrd.gz" => 'initrd.gz', "#{directory}/grubx64.efi" => 'grubx64.efi', "#{directory}/shimx64.efi" => 'shimx64.efi' },
      symlinks: { "#{directory}/boot.efi" => "#{directory}/grubx64.efi", "#{directory}/boot-sb.efi" => "#{directory}/shimx64.efi" }
    }
    Proxy::TFTP.extract_boot_files(request).join
    assert_equal 'source B', File.read(File.join(absolute, 'linux'))
    assert_equal 'source A', File.read(File.join(absolute, 'initrd.gz'))
    assert !File.exist?(File.join(absolute, 'netboot.tar.gz.source'))
    Zlib::GzipWriter.open(incoming) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        %w[linux initrd.gz grubx64.efi shimx64.efi].each do |name|
          tar.add_file_simple(name, 0o644, 8) { |file| file.write('source B') }
        end
      end
    end
    Proxy::TFTP.extract_boot_files(request).join
    assert_equal 'source B', File.read(File.join(absolute, 'initrd.gz'))
    assert Proxy::TFTP.validate_universe_boot_files!(os: 'debian', release: '12', arch: 'x86_64', kernel: "#{directory}/linux", initrd: "#{directory}/initrd.gz")
  ensure
    FileUtils.rm_rf(root) if root
  end
end
