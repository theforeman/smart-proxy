require 'test_helper'
require 'tftp/tftp_plugin'
require 'tftp/server'
require 'rubygems/package'
require 'rubygems/package/tar_writer'
require 'zlib'
class TftpFailedExtractionTest < Test::Unit::TestCase
  def test_failed_refresh_from_another_source_invalidates_readiness
    check_failed_refresh('https://source-b.test/netboot.tar.gz')
  end

  def test_failed_refresh_from_the_same_source_invalidates_readiness
    check_failed_refresh('https://source-a.test/netboot.tar.gz')
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
    assert_raise(RuntimeError) do
      Proxy::TFTP.validate_universe_boot_files!(os: 'debian', release: '12', arch: 'x86_64', archive: "#{directory}/netboot.tar.gz", kernel: "#{directory}/linux", initrd: "#{directory}/initrd.gz", source_digest: digest)
    end
    Zlib::GzipWriter.open(incoming) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        %w[linux initrd.gz grubx64.efi shimx64.efi].each do |name|
          tar.add_file_simple(name, 0o644, 8) { |file| file.write('source B') }
        end
      end
    end
    Proxy::TFTP.extract_boot_files(request).join
    assert_equal 'source B', File.read(File.join(absolute, 'initrd.gz'))
    assert Proxy::TFTP.validate_universe_boot_files!(os: 'debian', release: '12', arch: 'x86_64', archive: "#{directory}/netboot.tar.gz", kernel: "#{directory}/linux", initrd: "#{directory}/initrd.gz", source_digest: Digest::SHA256.hexdigest(source))
  ensure
    FileUtils.rm_rf(root) if root
  end
end
