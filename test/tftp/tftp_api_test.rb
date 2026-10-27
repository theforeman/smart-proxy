require 'test_helper'
require 'json'
require 'tmpdir'
require 'tftp/tftp_plugin'
require 'tftp/tftp_api'

ENV['RACK_ENV'] = 'test'

class TftpApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::TFTP::Api.new
  end

  def setup
    @tftp_root = Dir.mktmpdir('tftp-api-test-')
    Proxy::TFTP::Plugin.load_test_settings(:tftproot => @tftp_root)
    @args = {
      :pxeconfig => "foo",
      :menu => "bar",
    }
  end

  def teardown
    FileUtils.rm_rf(@tftp_root) if @tftp_root
  end

  def test_instantiate_syslinux
    obj = app.helpers.instantiate "syslinux", "AA:BB:CC:DD:EE:FF"
    assert_equal "Proxy::TFTP::Syslinux", obj.class.name
  end

  def test_instantiate_pxelinux
    obj = app.helpers.instantiate "pxelinux", "AA:BB:CC:DD:EE:FF"
    assert_equal "Proxy::TFTP::Pxelinux", obj.class.name
  end

  def test_instantiate_pxegrub2
    obj = app.helpers.instantiate "pxegrub2", "AA:BB:CC:DD:EE:FF"
    assert_equal "Proxy::TFTP::Pxegrub2", obj.class.name
  end

  def test_instantiate_ztp
    obj = app.helpers.instantiate "ztp", "AA:BB:CC:DD:EE:FF"
    assert_equal "Proxy::TFTP::Ztp", obj.class.name
  end

  def test_instantiate_poap
    obj = app.helpers.instantiate "poap", "AA:BB:CC:DD:EE:FF"
    assert_equal "Proxy::TFTP::Poap", obj.class.name
  end

  def test_instantiate_ipxe
    obj = app.helpers.instantiate "ipxe", "AA:BB:CC:DD:EE:FF"
    assert_equal "Proxy::TFTP::Ipxe", obj.class.name
  end

  def test_instantiate_nonexisting
    subject = app
    subject.helpers.expects(:log_halt).with(403, "Unrecognized pxeboot config type: Server").at_least(1)
    subject.helpers.instantiate "Server", "AA:BB:CC:DD:EE:FF"
  end

  def test_api_can_create_config
    mac = "aa:bb:cc:dd:ee:ff"
    Proxy::TFTP::Syslinux.any_instance.expects(:set).with(mac, @args[:pxeconfig]).returns(true)
    result = post "/#{mac}", @args
    assert last_response.ok?
    assert_equal '', result.body
  end

  def test_api_rejects_a_host_config_when_universe_files_are_not_ready
    mac = 'aa:bb:cc:dd:ee:ff'
    Proxy::TFTP::Pxegrub2.any_instance.expects(:set).never
    Proxy::TFTP.expects(:bootloader_universe_directories).returns([File.join(@tftp_root, 'universe')])
    Proxy::TFTP.expects(:validate_universe_boot_files!).raises('missing universe files')

    post "/PXEGrub2/#{mac}", @args.merge(
      targetos: 'debian', release: '12', arch: 'x86_64',
      universe_archive: 'bootloader-universe/pxegrub2/debian/12/x86_64/netboot.tar.gz',
      universe_kernel: 'bootloader-universe/pxegrub2/debian/12/x86_64/linux',
      universe_initrd: 'bootloader-universe/pxegrub2/debian/12/x86_64/initrd.gz',
      universe_source_digest: 'a' * 64
    )

    assert_equal 409, last_response.status
  end

  def test_api_accepts_a_host_config_when_universe_files_match
    mac = 'aa:bb:cc:dd:ee:ff'
    archive = 'bootloader-universe/pxegrub2/debian/12/x86_64/netboot.tar.gz'
    kernel = 'bootloader-universe/pxegrub2/debian/12/x86_64/linux'
    initrd = 'bootloader-universe/pxegrub2/debian/12/x86_64/initrd.gz'
    digest = 'a' * 64
    Proxy::TFTP.expects(:bootloader_universe_directories).returns([File.join(@tftp_root, 'universe')])
    Proxy::TFTP.expects(:validate_universe_boot_files!).with(
      os: 'debian', release: '12', arch: 'x86_64', kernel: kernel, initrd: initrd
    ).returns(true)
    Proxy::TFTP::Pxegrub2.any_instance.expects(:setup_bootloader).with(
      mac: mac, os: 'debian', release: '12', arch: 'x86_64', bootfile_suffix: nil, use_universe: true
    ).returns(true)
    Proxy::TFTP::Pxegrub2.any_instance.expects(:set).with(mac, 'foo').returns(true)

    post "/PXEGrub2/#{mac}", @args.merge(
      targetos: 'debian', release: '12', arch: 'x86_64',
      universe_archive: archive, universe_kernel: kernel,
      universe_initrd: initrd, universe_source_digest: digest
    )

    assert last_response.ok?
  end

  def test_api_accepts_manually_provided_universe_files_without_an_archive
    mac = 'aa:bb:cc:dd:ee:ff'
    directory = 'bootloader-universe/pxegrub2/centos_stream/10/x86_64'
    absolute_directory = File.join(@tftp_root, directory)
    FileUtils.mkdir_p(absolute_directory)
    %w[vmlinuz initrd.img grubx64.efi shimx64.efi].each do |name|
      File.write(File.join(absolute_directory, name), 'manual boot file')
    end
    File.symlink('grubx64.efi', File.join(absolute_directory, 'boot.efi'))
    File.symlink('shimx64.efi', File.join(absolute_directory, 'boot-sb.efi'))

    post "/PXEGrub2/#{mac}", @args.merge(
      targetos: 'centos_stream', release: '10', arch: 'x86_64',
      universe_archive: "#{directory}/boot.iso",
      universe_kernel: "#{directory}/vmlinuz", universe_initrd: "#{directory}/initrd.img"
    )

    assert last_response.ok?, last_response.body
    assert File.symlink?(File.join(@tftp_root, 'host-config/aa-bb-cc-dd-ee-ff/grub2/boot.efi'))
  end

  def test_api_reports_universe_file_readiness
    directory = 'bootloader-universe/pxegrub2/centos_stream/10/x86_64'
    absolute_directory = File.join(@tftp_root, directory)
    query = {
      targetos: 'centos_stream', release: '10', arch: 'x86_64',
      universe_kernel: "#{directory}/vmlinuz", universe_initrd: "#{directory}/initrd.img"
    }

    get '/universe_boot_files', query
    assert_equal false, JSON.parse(last_response.body)['ready']

    FileUtils.mkdir_p(absolute_directory)
    %w[vmlinuz initrd.img grubx64.efi shimx64.efi].each do |name|
      File.write(File.join(absolute_directory, name), 'manual boot file')
    end
    File.symlink('grubx64.efi', File.join(absolute_directory, 'boot.efi'))
    File.symlink('shimx64.efi', File.join(absolute_directory, 'boot-sb.efi'))

    get '/universe_boot_files', query
    assert_equal true, JSON.parse(last_response.body)['ready']

    Proxy::TFTP::DIR_LOCK.with_write([absolute_directory]) do
      get '/universe_boot_files', query
      assert_equal false, JSON.parse(last_response.body)['ready']
    end
  end

  def test_api_reports_universe_files_unready_without_creating_the_tftp_root
    root = File.join(@tftp_root, 'absent')
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns(root)
    directory = 'bootloader-universe/pxegrub2/centos_stream/10/x86_64'

    query = {
      targetos: 'centos_stream', release: '10', arch: 'x86_64',
      universe_kernel: "#{directory}/vmlinuz", universe_initrd: "#{directory}/initrd.img"
    }
    get '/universe_boot_files', query

    assert_equal false, JSON.parse(last_response.body)['ready']
    assert !File.exist?(root)
  end

  def test_legacy_pxegrub2_config_does_not_reserve_universe_files
    mac = 'aa:bb:cc:dd:ee:ff'
    directory = File.join(@tftp_root, 'bootloader-universe/pxegrub2/centos_stream/10/x86_64')
    Proxy::TFTP::Pxegrub2.any_instance.expects(:setup_bootloader).with(
      mac: mac, os: 'centos_stream', release: '10', arch: 'x86_64', bootfile_suffix: nil, use_universe: false
    ).returns(true)
    Proxy::TFTP::Pxegrub2.any_instance.expects(:set).with(mac, 'foo').returns(true)

    Proxy::TFTP::DIR_LOCK.with_write([directory]) do
      post "/PXEGrub2/#{mac}", @args.merge(targetos: 'centos_stream', release: '10', arch: 'x86_64')
      assert last_response.ok?, last_response.body
    end
  end

  def test_api_can_create_config_64bit
    mac = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd"
    Proxy::TFTP::Syslinux.any_instance.expects(:set).with(mac, "foo").returns(true)
    result = post "/#{mac}", @args
    assert last_response.ok?
    assert_equal '', result.body
  end

  def test_api_returns_error_when_invalid_mac
    post "/aa:bb:cc:00:11:zz", @args
    assert !last_response.ok?
    assert_equal "Invalid MAC address: aa:bb:cc:00:11:zz", last_response.body
  end

  def test_api_can_read_config
    mac = "aa:bb:cc:dd:ee:ff"
    Proxy::TFTP::Syslinux.any_instance.expects(:get).with(mac).returns('foo')
    result = get "/syslinux/#{mac}"
    assert last_response.ok?
    assert_equal 'foo', result.body
  end

  def test_api_can_remove_config
    mac = "aa:bb:cc:dd:ee:ff"
    Proxy::TFTP::Syslinux.any_instance.expects(:del).with(mac).returns(true)
    result = delete "/#{mac}"
    assert last_response.ok?
    assert_equal '', result.body
  end

  def test_api_can_create_defatult
    Proxy::TFTP::Syslinux.any_instance.expects(:create_default).with(@args[:menu]).returns(true)
    post "/create_default", @args
    assert last_response.ok?
  end

  def test_api_can_fetch_boot_file
    boot_file = File.join(@tftp_root, 'boot/file')
    Proxy::TFTP.expects(:fetch_boot_file).with(boot_file, 'http://localhost/file').returns(true)
    post "/fetch_boot_file", :prefix => boot_file, :path => 'http://localhost/file'
    assert last_response.ok?
  end

  def test_api_can_fetch_and_process_a_file_to_an_exact_destination
    Proxy::TFTP.expects(:fetch_boot_file).with(
      'bootloader-universe/pxegrub2/ubuntu/26.04/amd64/boot.iso',
      'https://example.test/ubuntu.iso',
      nil,
      exact_destination: true
    ).returns(true)
    post "/fetch_and_process", JSON.generate(
      destination: 'bootloader-universe/pxegrub2/ubuntu/26.04/amd64/boot.iso',
      source: 'https://example.test/ubuntu.iso'
    ), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
  end

  def test_api_can_queue_json_extraction_request
    extract = {
      :source => 'https://localhost/netboot.tar.gz',
      :destination => 'bootloader-universe/debian/netboot.tar.gz',
      :type => 'tgz',
      :files => { 'bootloader-universe/debian/grubx64.efi' => 'debian-installer/amd64/grubx64.efi' },
      :symlinks => { 'bootloader-universe/debian/boot.efi' => 'bootloader-universe/debian/grubx64.efi' },
    }
    Proxy::TFTP.expects(:fetch_boot_file).with(nil, nil, JSON.parse(JSON.generate(extract))).returns(true)
    post "/fetch_and_process", JSON.generate(:extract => extract), 'CONTENT_TYPE' => 'application/json'
    assert last_response.ok?
  end

  def test_api_can_get_servername
    Proxy::TFTP::Plugin.settings.stubs(:tftp_servername).returns("servername")
    result = get "/serverName"
    assert_match /servername/, result.body
    assert last_response.ok?
  end
end
