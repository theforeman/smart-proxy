require 'test_helper'
require 'json'
require 'sinatra'
require 'tftp/tftp_plugin'
require 'tftp/tftp_api'

ENV['RACK_ENV'] = 'test'

class TftpApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::TFTP::Api.new
  end

  def setup
    Proxy::TFTP::Plugin.settings.stubs(:tftproot).returns("/some/root")
    @args = { :pxeconfig => "foo" }
  end

  def test_api_can_fetch_boot_file
    Proxy::Util::CommandTask.stubs(:new).returns(true)
    FileUtils.stubs(:mkdir_p).returns(true)
    Proxy::TFTP.expects(:fetch_boot_file).with('/some/root/boot/file','http://localhost/file').returns(true)
    post "/fetch_boot_file", {:prefix => '/some/root/boot/file', :path => 'http://localhost/file'}
    assert last_response.ok?
  end

  def test_api_can_create_syslinux_tftp_reservation
    mac = "aa:bb:cc:00:11:22"
    mac_filename = "aa-bb-cc-dd-ee-ff-00-11-22"
    FileUtils.stubs(:mkdir_p).returns(true)
    File.stubs(:open).with("/some/root/pxelinux.cfg/#{mac_filename}", 'w').returns(true)
    Proxy::TFTP::Syslinux.any_instance.expects(:set).with(mac, args[:pxeconfig])
    post "/#{mac}", args
    assert last_response.ok?
  end

  def test_api_can_create_syslinux_tftp_reservation_for_64bit_mac
    mac = "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd"
    mac_filename = "aa-bb-cc-dd-ee-ff-00-11-22-33-44-55-66-77-88-99-aa-bb-cc-dd"
    FileUtils.stubs(:mkdir_p).returns(true)
    File.stubs(:open).with("/some/root/pxelinux.cfg/#{mac_filename}", 'w').returns(true)
    Proxy::TFTP::Syslinux.any_instance.expects(:set).with(mac, args[:pxeconfig])
    post "/#{mac}", args
    assert last_response.ok?
  end

  def test_api_returns_error_when_invalid_mac
    post "/aa:bb:cc:00:11:zz", args
    assert !last_response.ok?
    assert_equal "Invalid MAC address: aa:bb:cc:00:11:zz", last_response.body
  end

  def test_api_can_create_default
    params = { :menu => "foobar" }
    Proxy::TFTP::Syslinux.any_instance.expects(:create_default).with(params[:menu])
    post "/create_default", params
  end

  private
  attr_reader :args

end
