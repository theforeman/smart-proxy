require 'test_helper'
require 'helpers'
require 'json'
require 'abrtproxy_api'
require 'ostruct'
require 'webrick'

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

  def test_forwarding_to_foreman
    Proxy::Request::Reports.any_instance.expects(:post_report)

    post "/abrt/reports/new/", @post_data

    assert last_response.successful?
    assert_equal last_response.status, 202
    data = JSON.parse(last_response.body)
    assert_equal data['result'], false
    assert data['message'].is_a?(String), "Response message is not string"
  end

  def test_forwarding_to_foreman_and_faf
    response_body = {
      "result"  => true,
      "message" => "Hi!"
    }.to_json
    response_status = 202
    faf_response = OpenStruct.new(:code => response_status, :body => response_body)

    Proxy::AbrtProxy.expects(:faf_request).returns(faf_response)
    Proxy::Request::Reports.any_instance.expects(:post_report).returns(nil)
    SETTINGS.stubs(:abrt_server_url).returns('https://doesnt.matter/')

    post "/abrt/reports/new/", @post_data

    assert last_response.successful?
    assert_equal last_response.status, response_status
    assert_equal last_response.body, response_body
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

  def test_multipart_form_data_file
    file_contents = '{"foo":"bar"}'
    headers, body = Proxy::AbrtProxy.form_data_file(file_contents, 'application/json')
    request_text = "POST /abrt/whatever/ HTTP/1.1\r\n"
    headers.each do |key,value|
      request_text << key + ": " + value + "\r\n"
    end
    request_text << "\r\n"
    request_text << body

    req = WEBrick::HTTPRequest.new(WEBrick::Config::HTTP)
    req.parse(StringIO.new(request_text))

    assert_equal req.request_method, "POST"
    assert_equal req.query["file"], file_contents
  end
end
