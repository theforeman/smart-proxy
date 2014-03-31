require 'test_helper'
require 'helpers'
require 'json'
require 'abrtproxy_api'
require 'ostruct'
require 'webrick'
require 'tmpdir'

ENV['RACK_ENV'] = 'test'

class AbrtApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    SmartProxy.new
  end

  def setup
    ureport_file = "test/fixtures/abrt/ureport1.json"
    @post_data = {
      "file" => Rack::Test::UploadedFile.new(ureport_file, "application/json")
    }
    Proxy::AbrtProxy.stubs(:common_name).returns('localhost')
  end

  def assert_dir_contains_report(dir)
    files = Dir[File.join(dir, "ureport-*")]
    assert_equal files.size, 1
    report_json = IO.read(files[0])
    report = JSON.parse report_json
    assert report.has_key?("host"), "On disk report has no host key"
    assert report.has_key?("report"), "On disk report does not contain report"
  end

  def test_forwarding_to_foreman
    Dir.mktmpdir do |tmpdir|
      SETTINGS.stubs(:abrt_spooldir).returns(tmpdir)

      post "/abrt/reports/new/", @post_data

      assert last_response.successful?
      assert_equal last_response.status, 202
      data = JSON.parse(last_response.body)
      assert_equal data['result'], false
      assert data['message'].is_a?(String), "Response message is not string"

      assert_dir_contains_report tmpdir
    end
  end

  def test_forwarding_to_foreman_and_faf
    response_body = {
      "result"  => true,
      "message" => "Hi!"
    }.to_json
    response_status = 202
    faf_response = OpenStruct.new(:code => response_status, :body => response_body)

    Proxy::AbrtProxy.expects(:faf_request).returns(faf_response)
    SETTINGS.stubs(:abrt_server_url).returns('https://doesnt.matter/')

    Dir.mktmpdir do |tmpdir|
      SETTINGS.stubs(:abrt_spooldir).returns(tmpdir)

      post "/abrt/reports/new/", @post_data

      assert last_response.successful?
      assert_equal last_response.status, response_status
      assert_equal last_response.body, response_body

      assert_dir_contains_report tmpdir
    end
  end

  def test_forwarding_other_endpoints
    post "/abrt/reports/attach/", @post_data

    assert_equal last_response.status, 501

    faf_response = OpenStruct.new(:code => 201, :body => "Whatever!")
    Proxy::AbrtProxy.expects(:faf_request).returns(faf_response)
    SETTINGS.stubs(:abrt_server_url).returns('https://doesnt.matter/')

    post "/abrt/reports/attach/", @post_data

    assert_equal last_response.status, faf_response.code
    assert_equal last_response.body, faf_response.body
  end
end
