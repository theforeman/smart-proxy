require 'test_helper'
require 'tftp/server'
require 'tftp/tftp_plugin'
require 'tempfile'

module TftpGenericServerSuite
  def setup
    @rootdir = "/some/root"
    @mac = "aa:bb:cc:dd:ee:ff"
    @content = "file content"
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(@rootdir)
    setup_paths
  end

  def pxe_config_files
    @pxe_config_files.collect { |f| File.join(@rootdir, f) }
  end

  def pxe_default_files
    @pxe_default_files.collect { |f| File.join(@rootdir, f) }
  end

  def test_set
    pxe_config_files.each do |file|
      @subject.expects(:write_file).with(file, @content).once
    end
    @subject.set @mac, @content
  end

  def test_del
    pxe_config_files.each do |file|
      @subject.expects(:delete_file).with(file).once
    end
    @subject.del @mac
  end

  def test_get
    file = pxe_config_files.first
    @subject.expects(:read_file).with(file).returns(@content)
    assert_equal @content, @subject.get(@mac)
  end

  def test_create_default
    pxe_default_files.each do |file|
      @subject.expects(:write_file).with(file, @content).once
    end
    @subject.create_default @content
  end

  def test_dashed_mac
    assert "aa-bb-cc-dd-ee-ff", @subject.dashed_mac(@mac)
  end
end

class HelperServerTest < Test::Unit::TestCase
  def setup
    @subject = Proxy::TFTP::Server.new
  end

  def test_path_with_settings
    Proxy::TFTP::Plugin.settings.expects(:tftproot).returns("/some/root")
    assert_equal "/some/root", @subject.path
  end

  def test_path
    assert_match /file.txt/, @subject.path("file.txt")
  end

  def test_read_file
    file = Tempfile.new('foreman-proxy-tftp-server-read-file.txt')
    file.write("test")
    file.close
    assert_equal ["test"], @subject.read_file(file.path)
  ensure
    file.unlink
  end

  def test_write_file
    tmp_filename = File.join(Dir.tmpdir(), 'foreman-proxy-tftp-server-write-file.txt')
    @subject.write_file(tmp_filename, "test")
    assert_equal "test", File.open(tmp_filename, "rb").read
  ensure
    File.unlink(tmp_filename) if tmp_filename
  end

  def test_delete_file
    tmp_filename = File.join(Dir.tmpdir(), 'foreman-proxy-tftp-server-write-file.txt')
    @subject.delete_file tmp_filename
    assert_equal false, File.exist?(tmp_filename)
  ensure
    File.unlink(tmp_filename) if File.exist?(tmp_filename)
  end
end

class TftpSyslinuxServerTest < Test::Unit::TestCase
  include TftpGenericServerSuite

  def setup_paths
    @subject = Proxy::TFTP::Syslinux.new
    @pxe_config_files = ["pxelinux.cfg/01-aa-bb-cc-dd-ee-ff"]
    @pxe_default_files = ["pxelinux.cfg/default"]
  end
end

class TftpPxegrub2ServerTest < Test::Unit::TestCase
  include TftpGenericServerSuite

  def setup
    @arch = "x86_64"
    @bootfile_suffix = "x64"
    @os = "redhat"
    @release = "9.4"
    super
  end

  def setup_paths
    @subject = Proxy::TFTP::Pxegrub2.new
    @pxe_config_files = [
      "host-config/aa-bb-cc-dd-ee-ff/grub2/grub.cfg",
      "host-config/aa-bb-cc-dd-ee-ff/grub2/grub.cfg-01-aa-bb-cc-dd-ee-ff",
      "host-config/aa-bb-cc-dd-ee-ff/grub2/grub.cfg-aa:bb:cc:dd:ee:ff",
      "grub2/grub.cfg-01-aa-bb-cc-dd-ee-ff",
      "grub2/grub.cfg-aa:bb:cc:dd:ee:ff",
    ]
    @pxe_default_files = ["grub2/grub.cfg"]
  end

  def test_pxeconfig_dir
    assert_equal File.join(@subject.path, "host-config", @subject.dashed_mac(@mac).downcase, "grub2"), @subject.pxeconfig_dir(@mac)
    assert_equal File.join(@subject.path, "grub2"), @subject.pxeconfig_dir()
  end

  def test_release_specific_bootloader_path
    release_specific_bootloader_path = File.join(@subject.path, "bootloader-universe", "pxegrub2", @os, @release, @arch)
    Dir.stubs(:exist?).with(release_specific_bootloader_path).returns(true).once
    assert_equal release_specific_bootloader_path, @subject.bootloader_path(@os, @release, @arch)
  end

  def test_default_bootloader_path
    release_specific_bootloader_path = File.join(@subject.path, "bootloader-universe", "pxegrub2", @os, @release, @arch)
    default_bootloader_path = File.join(@subject.path, "bootloader-universe", "pxegrub2", @os, "default", @arch)
    Dir.stubs(:exist?).with(release_specific_bootloader_path).returns(false).once
    Dir.stubs(:exist?).with(default_bootloader_path).returns(true).once
    assert_equal default_bootloader_path, @subject.bootloader_path(@os, @release, @arch)
  end

  def test_bootloader_universe_symlinks
    temp_dir = Dir.mktmpdir()
    pxeconfig_dir_mac = @subject.pxeconfig_dir(@mac)
    symlinks = [
      { source: File.join(temp_dir, "dummy1.efi"), symlink: File.join(pxeconfig_dir_mac, "dummy1.efi") },
      { source: File.join(temp_dir, "dummy2.efi"), symlink: File.join(pxeconfig_dir_mac, "dummy2.efi") },
    ]
    symlinks.each do |entry|
      FileUtils.touch(entry[:source])
    end
    assert_equal(
      symlinks.sort_by { |entry| entry[:source] },
      @subject.bootloader_universe_symlinks(temp_dir, pxeconfig_dir_mac).sort_by { |entry| entry[:source] }
    )
  end

  def test_default_symlinks
    pxeconfig_dir = @subject.pxeconfig_dir
    pxeconfig_dir_mac = @subject.pxeconfig_dir(@mac)
    symlinks = [
      { source: File.join(pxeconfig_dir, "grub#{@bootfile_suffix}.efi"), symlink: File.join(pxeconfig_dir_mac, "boot.efi") },
      { source: File.join(pxeconfig_dir, "grub#{@bootfile_suffix}.efi"), symlink: File.join(pxeconfig_dir_mac, "grub#{@bootfile_suffix}.efi") },
      { source: File.join(pxeconfig_dir, "shim#{@bootfile_suffix}.efi"), symlink: File.join(pxeconfig_dir_mac, "boot-sb.efi") },
      { source: File.join(pxeconfig_dir, "shim#{@bootfile_suffix}.efi"), symlink: File.join(pxeconfig_dir_mac, "shim#{@bootfile_suffix}.efi") },
    ]
    assert_equal symlinks, @subject.default_symlinks(@bootfile_suffix, @subject.pxeconfig_dir(@mac))
  end

  def test_create_symlinks
    symlinks = [
      { source: "/path/to/source1", symlink: "/path/to/symlink1" },
      { source: "/path/to/source2", symlink: "/another/path/to/symlink2" },
    ]
    FileUtils.expects(:ln_s).with("source1", "/path/to/symlink1", {:force => true}).once
    FileUtils.expects(:ln_s).with("../../../path/to/source2", "/another/path/to/symlink2", {:force => true}).once
    @subject.create_symlinks(symlinks)
  end

  def test_del
    pxe_config_files.each do |file|
      @subject.expects(:delete_file).with(file).once
    end
    @subject.expects(:delete_host_dir).with(@mac).once
    @subject.del @mac
  end
end

class TftpPoapServerTest < Test::Unit::TestCase
  include TftpGenericServerSuite

  def setup_paths
    @subject = Proxy::TFTP::Poap.new
    @pxe_config_files = ["poap.cfg/AABBCCDDEEFF"]
  end

  def test_create_default
    # default template not supported in this case
  end
end

class TftpZtpServerTest < Test::Unit::TestCase
  include TftpGenericServerSuite

  def setup_paths
    @subject = Proxy::TFTP::Ztp.new
    @pxe_config_files = ["ztp.cfg/AABBCCDDEEFF", "ztp.cfg/AABBCCDDEEFF.cfg"]
  end

  def test_create_default
    # default template not supported in this case
  end
end

class TftpIpxeServerTest < Test::Unit::TestCase
  include TftpGenericServerSuite

  def setup_paths
    @subject = Proxy::TFTP::Ipxe.new
    @pxe_config_files = ["pxelinux.cfg/01-aa-bb-cc-dd-ee-ff.ipxe"]
    @pxe_default_files = ["pxelinux.cfg/default.ipxe"]
  end
end
