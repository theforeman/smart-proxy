require 'test_helper'
require 'helpers'
require 'pulp_api'
require 'webmock/test_unit'

ENV['RACK_ENV'] = 'test'

class PulpApiTest < Test::Unit::TestCase
  PULP_STATUS_URL = "/api/v2/status/"
  include Rack::Test::Methods

  def app
    SmartProxy.new
  end

  def setup
    SETTINGS.stubs(:pulp_url).returns("https://pulp.local")
  end

  def test_ok_response
    stub_request(:get, SETTINGS.pulp_url + PULP_STATUS_URL)
    get "/pulp/status"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
  end

  def test_pulp_500_response
    stub_request(:get, SETTINGS.pulp_url + PULP_STATUS_URL).to_return(:status => 500) #Net::HTTPServerError.new("1.1", 500, "Pulp server is down"))
    get "/pulp/status"
    assert last_response.body.include?("500")
  end

  def test_pulp_down_response
    stub_request(:get, SETTINGS.pulp_url + PULP_STATUS_URL).to_raise(Errno::ECONNREFUSED)
    get "/pulp/status"
    assert_equal 503, last_response.status
  end

  def test_pulp_server_unknown_response
    stub_request(:get, SETTINGS.pulp_url + PULP_STATUS_URL).to_raise(SocketError)
    get "/pulp/status"
    assert_equal 503, last_response.status
  end
end
