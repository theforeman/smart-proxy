require 'test_helper'
require 'json'
require 'tempfile'
require 'uri'
require 'webrick'
require 'rubygems/package'
require 'rubygems/package/tar_writer'
require 'zlib'
require 'tftp/tftp_plugin'
require 'tftp/tftp_api'

class TftpApiExtractionInProgressIntegrationTest < Test::Unit::TestCase
  def test_host_config_fails_fast_while_real_archive_download_is_in_progress
    tftp_root = Dir.mktmpdir('tftp-sync-integration-')
    universe_path = 'bootloader-universe/pxegrub2/debian/12/x86_64'
    universe_dir = File.join(tftp_root, universe_path)
    Proxy::TFTP::Plugin.load_test_settings(
      tftproot: tftp_root,
      tftp_connect_timeout: 5,
      tftp_download_max_time: 30,
      tftp_http_download_preflight: false,
      verify_server_cert: true
    )

    archive = fake_archive
    download_started = Queue.new
    allow_download = Queue.new
    server = WEBrick::HTTPServer.new(
      Port: 0,
      BindAddress: '127.0.0.1',
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
    server.mount_proc('/netboot.tar.gz') do |request, response|
      if request.request_method == 'HEAD'
        response.status = 200
      else
        download_started << true
        allow_download.pop
        response.body = archive
      end
    end
    server_thread = Thread.new { server.start }
    source = "http://127.0.0.1:#{server.listeners.first.addr[1]}/netboot.tar.gz"
    extract_payload = {
      source: source,
      destination: "#{universe_path}/netboot.tar.gz",
      type: 'tgz',
      files: {
        "#{universe_path}/grubx64.efi" => 'boot/grub2/grubx64.efi',
        "#{universe_path}/shimx64.efi" => 'boot/grub2/shimx64.efi',
        "#{universe_path}/linux" => 'boot/linux',
        "#{universe_path}/initrd.gz" => 'boot/initrd.gz',
      },
      symlinks: {
        "#{universe_path}/boot.efi" => "#{universe_path}/grubx64.efi",
        "#{universe_path}/boot-sb.efi" => "#{universe_path}/shimx64.efi",
      },
    }
    extract_response = api_request.post(
      '/fetch_and_process',
      input: JSON.generate(extract: extract_payload),
      'CONTENT_TYPE' => 'application/json'
    )
    assert_equal 200, extract_response.status, extract_response.body

    Timeout.timeout(5) { download_started.pop }

    duplicate_extract_response = api_request.post(
      '/fetch_and_process',
      input: JSON.generate(extract: extract_payload),
      'CONTENT_TYPE' => 'application/json'
    )
    assert_equal 409, duplicate_extract_response.status, duplicate_extract_response.body

    mac = 'aa:bb:cc:dd:ee:ff'
    host_response = Timeout.timeout(1) do
      api_request.post(
        "/pxegrub2/#{mac}",
        input: URI.encode_www_form(
          targetos: 'debian',
          release: '12',
          arch: 'x86_64',
          bootfile_suffix: 'x64',
          pxeconfig: 'set default=0'
        ),
        'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
      )
    end
    assert_equal 409, host_response.status, host_response.body
    assert_match(/currently being downloaded or extracted/, host_response.body)

    allow_download << true
    Timeout.timeout(10) do
      Thread.pass while Proxy::TFTP::DIR_LOCK.active?(universe_dir)
    end
  ensure
    allow_download << true if allow_download
    if universe_dir
      begin
        Timeout.timeout(10) do
          Thread.pass while Proxy::TFTP::DIR_LOCK.active?(universe_dir)
        end
      rescue Timeout::Error
        # Continue teardown if the worker is the failure under test.
      end
    end
    server&.shutdown
    server_thread&.join
    FileUtils.rm_rf(tftp_root) if tftp_root
  end

  def test_direct_universe_download_is_async_and_blocks_host_config
    tftp_root = Dir.mktmpdir('tftp-direct-download-')
    universe_path = 'bootloader-universe/pxegrub2/debian/12/x86_64'
    universe_dir = File.join(tftp_root, universe_path)
    destination = "#{universe_path}/netboot.tar.gz"
    Proxy::TFTP::Plugin.load_test_settings(
      tftproot: tftp_root,
      tftp_connect_timeout: 5,
      tftp_download_max_time: 30,
      tftp_http_download_preflight: true,
      verify_server_cert: true
    )

    preflight_started = Queue.new
    allow_preflight = Queue.new
    download_started = Queue.new
    allow_download = Queue.new
    server = WEBrick::HTTPServer.new(
      Port: 0,
      BindAddress: '127.0.0.1',
      Logger: WEBrick::Log.new(File::NULL),
      AccessLog: []
    )
    server.mount_proc('/netboot.tar.gz') do |request, response|
      if request.request_method == 'HEAD'
        preflight_started << true
        allow_preflight.pop
        response.status = 200
      else
        download_started << true
        allow_download.pop
        response.body = 'archive payload'
      end
    end
    server_thread = Thread.new { server.start }
    source = "http://127.0.0.1:#{server.listeners.first.addr[1]}/netboot.tar.gz"
    stub_request(:head, source).to_return do
      preflight_started << true
      allow_preflight.pop
      { status: 200 }
    end

    response = Timeout.timeout(1) do
      api_request.post(
        '/fetch_and_process',
        input: JSON.generate(destination: destination, source: source),
        'CONTENT_TYPE' => 'application/json'
      )
    end
    assert_equal 200, response.status, response.body
    Timeout.timeout(5) { preflight_started.pop }

    duplicate_download_response = Timeout.timeout(1) do
      api_request.post(
        '/fetch_and_process',
        input: JSON.generate(destination: destination, source: source),
        'CONTENT_TYPE' => 'application/json'
      )
    end
    assert_equal 409, duplicate_download_response.status, duplicate_download_response.body

    host_response = api_request.post(
      '/pxegrub2/aa:bb:cc:dd:ee:ff',
      input: URI.encode_www_form(
        targetos: 'debian', release: '12', arch: 'x86_64',
        bootfile_suffix: 'x64', pxeconfig: 'set default=0'
      ),
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
    )
    assert_equal 409, host_response.status, host_response.body

    allow_preflight << true
    Timeout.timeout(5) { download_started.pop }
    allow_download << true
    Timeout.timeout(10) do
      Thread.pass while Proxy::TFTP::DIR_LOCK.active?(universe_dir)
    end
    assert_equal 'archive payload', File.read(File.join(tftp_root, destination))
  ensure
    allow_preflight << true if allow_preflight
    allow_download << true if allow_download
    if universe_dir
      begin
        Timeout.timeout(10) do
          Thread.pass while Proxy::TFTP::DIR_LOCK.active?(universe_dir)
        end
      rescue Timeout::Error
        # Continue teardown if the worker is the failure under test.
      end
    end
    server&.shutdown
    server_thread&.join
    FileUtils.rm_rf(tftp_root) if tftp_root
  end

  private

  def api_request
    Rack::MockRequest.new(Proxy::TFTP::Api.new)
  end

  def fake_archive
    files = {
      'boot/grub2/grubx64.efi' => 'fake efi payload',
      'boot/grub2/shimx64.efi' => 'fake shim payload',
      'boot/linux' => 'fake kernel payload',
      'boot/initrd.gz' => 'fake initramdisk payload',
    }
    Tempfile.create('fake-netboot') do |file|
      Zlib::GzipWriter.open(file.path) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |tar|
          files.each do |name, payload|
            tar.add_file_simple(name, 0o644, payload.bytesize) do |entry|
              entry.write(payload)
            end
          end
        end
      end
      File.binread(file.path)
    end
  end
end
