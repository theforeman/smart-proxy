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
    @pxe_config_files.collect{|f| File.join(@rootdir, f)}
  end

  def pxe_default_files
    @pxe_default_files.collect{|f| File.join(@rootdir, f)}
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

class TftpPxegrubServerTest < Test::Unit::TestCase
  include TftpGenericServerSuite

  def setup_paths
    @subject = Proxy::TFTP::Pxegrub.new
    @pxe_config_files = ["grub/menu.lst.01AABBCCDDEEFF", "grub/01-AA-BB-CC-DD-EE-FF"]
    @pxe_default_files = ["grub/menu.lst", "grub/efidefault"]
  end
end

class TftpPxegrub2ServerTest < Test::Unit::TestCase
  include TftpGenericServerSuite

  def setup_paths
    @subject = Proxy::TFTP::Pxegrub2.new
    @pxe_config_files = ["grub2/grub.cfg-01-aa-bb-cc-dd-ee-ff"]
    @pxe_default_files = ["grub2/grub.cfg"]
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
    @pxe_config_files = ["ztp.cfg/AABBCCDDEEFF"]
  end

  def test_create_default
    # default template not supported in this case
  end
end
