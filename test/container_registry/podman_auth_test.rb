require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'proxy/container_registry/podman_auth'

class PodmanAuthTest < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir

    @cert_file = File.join(@tmpdir, 'client.crt')
    @key_file  = File.join(@tmpdir, 'client.key')
    @ca_file   = File.join(@tmpdir, 'ca.crt')

    File.write(@cert_file, 'CERT')
    File.write(@key_file,  'KEY')
    File.write(@ca_file,   'CA')

    Proxy::SETTINGS.stubs(:foreman_ssl_cert).returns(@cert_file)
    Proxy::SETTINGS.stubs(:foreman_ssl_key).returns(@key_file)
    Proxy::SETTINGS.stubs(:foreman_ssl_ca).returns(@ca_file)
    Proxy::SETTINGS.stubs(:ssl_certificate).returns(nil)
    Proxy::SETTINGS.stubs(:ssl_private_key).returns(nil)
    Proxy::SETTINGS.stubs(:ssl_ca_file).returns(nil)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_setup_cert_dir_creates_temp_dir
    dir = Proxy::ContainerRegistry::PodmanAuth.setup_cert_dir
    assert Dir.exist?(dir)
  ensure
    Proxy::ContainerRegistry::PodmanAuth.cleanup(dir)
  end

  def test_setup_cert_dir_symlinks_cert_files
    dir = Proxy::ContainerRegistry::PodmanAuth.setup_cert_dir
    assert File.symlink?(File.join(dir, 'client.cert'))
    assert File.symlink?(File.join(dir, 'client.key'))
    assert File.symlink?(File.join(dir, 'ca.crt'))
    assert_equal 'CERT', File.read(File.join(dir, 'client.cert'))
    assert_equal 'KEY',  File.read(File.join(dir, 'client.key'))
    assert_equal 'CA',   File.read(File.join(dir, 'ca.crt'))
  ensure
    Proxy::ContainerRegistry::PodmanAuth.cleanup(dir)
  end

  def test_setup_cert_dir_falls_back_to_ssl_settings
    Proxy::SETTINGS.stubs(:foreman_ssl_cert).returns(nil)
    Proxy::SETTINGS.stubs(:foreman_ssl_key).returns(nil)
    Proxy::SETTINGS.stubs(:foreman_ssl_ca).returns(nil)
    Proxy::SETTINGS.stubs(:ssl_certificate).returns(@cert_file)
    Proxy::SETTINGS.stubs(:ssl_private_key).returns(@key_file)
    Proxy::SETTINGS.stubs(:ssl_ca_file).returns(@ca_file)

    dir = Proxy::ContainerRegistry::PodmanAuth.setup_cert_dir
    assert_equal 'CERT', File.read(File.join(dir, 'client.cert'))
    assert_equal 'KEY',  File.read(File.join(dir, 'client.key'))
  ensure
    Proxy::ContainerRegistry::PodmanAuth.cleanup(dir)
  end

  def test_setup_cert_dir_skips_missing_ca
    Proxy::SETTINGS.stubs(:foreman_ssl_ca).returns(nil)
    Proxy::SETTINGS.stubs(:ssl_ca_file).returns(nil)

    dir = Proxy::ContainerRegistry::PodmanAuth.setup_cert_dir
    refute File.exist?(File.join(dir, 'ca.crt'))
  ensure
    Proxy::ContainerRegistry::PodmanAuth.cleanup(dir)
  end

  def test_cleanup_removes_cert_dir
    dir = Proxy::ContainerRegistry::PodmanAuth.setup_cert_dir
    Proxy::ContainerRegistry::PodmanAuth.cleanup(dir)
    refute Dir.exist?(dir)
  end

  def test_cleanup_ignores_nil
    assert_nothing_raised { Proxy::ContainerRegistry::PodmanAuth.cleanup(nil) }
  end

  def test_tls_args_includes_cert_dir
    args = Proxy::ContainerRegistry::PodmanAuth.tls_args('/some/path')
    assert_match %r{--tls-verify=true}, args
    assert_match %r{--cert-dir /some/path}, args
  end

  def test_tls_args_escapes_spaces_in_path
    args = Proxy::ContainerRegistry::PodmanAuth.tls_args('/some/path with spaces')
    assert_match %r{--cert-dir }, args
    refute_match %r{--cert-dir /some/path with spaces}, args
  end
end
