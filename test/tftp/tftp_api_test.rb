require 'test_helper'
require 'json'
require 'tftp/plugin_configuration'
require 'tftp/tftp_plugin'
require 'tftp/dependency_injection'
require 'tftp/server'
require 'tftp/tftp_api'
require 'tftp/http_downloads'

ENV['RACK_ENV'] = 'test'

class TftpApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  class HttpDownloadsForTesting < ::Proxy::TFTP::HttpDownloads; attr_accessor :id_to_download; end
  class HttpDownloadForTesting < ::Proxy::TFTP::HttpDownload; attr_accessor :status; end
  class HttpDownloadStatusForTesting < ::Proxy::TFTP::HttpDownload::Status
    def initialize(length, downloaded, timestamp)
      super(timestamp)
      @file_length = length
      @downloaded = downloaded
    end
  end

  def app
    app = Proxy::TFTP::Api.new
    app.helpers.boot_file_downloader = @boot_file_downloader
    app
  end

  def setup
    @boot_file_downloader = HttpDownloadsForTesting.new('/some/root')
    Proxy::TFTP::Plugin.load_test_settings(:tftproot => "/some/root")
    @args = {
      :pxeconfig => "foo",
      :menu => "bar"
    }
  end

  def test_instantiate_syslinux
    obj = app.helpers.instantiate "syslinux", "AA:BB:CC:DD:EE:FF"
    assert_equal "Proxy::TFTP::Syslinux", obj.class.name
  end

  def test_instantiate_pxelinux
    obj = app.helpers.instantiate "pxelinux", "AA:BB:CC:DD:EE:FF"
    assert_equal "Proxy::TFTP::Pxelinux", obj.class.name
  end

  def test_instantiate_pxegrub
    obj = app.helpers.instantiate "pxegrub", "AA:BB:CC:DD:EE:FF"
    assert_equal "Proxy::TFTP::Pxegrub", obj.class.name
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

  def test_api_can_download_boot_file
    @boot_file_downloader.expects(:download).with('/some/root/boot/file','http://localhost/file').returns('123456')
    result = post "/fetch_boot_file", :prefix => '/some/root/boot/file', :path => 'http://localhost/file'
    assert last_response.ok?
    assert_equal '123456', result.body
  end

  def test_get_download_status
    status = HttpDownloadStatusForTesting.new(100, 50, now = Time.now)
    @boot_file_downloader.id_to_download['123456'] = ::Proxy::TFTP::HttpDownload.new('test', 'http://localhost', status)
    result = get "/fetch_boot_file_status/123456"
    assert_equal({:file_length => 100, :downloaded => 50, :progress => 50, :timestamp => now, :last_error => nil}.to_json, result.body)
  end

  def test_get_download_status_returns_404_if_id_is_unknown
    get "/fetch_boot_file_status/123456"
    assert_false last_response.ok?
    assert_equal 404, last_response.status
  end

  def test_api_can_get_servername
    Proxy::TFTP::Plugin.settings.stubs(:tftp_servername).returns("servername")
    result = get "/serverName"
    assert_match /servername/, result.body
    assert last_response.ok?
  end
end
