require 'test_helper'
require 'json'
require 'logs/logs_api'

ENV['RACK_ENV'] = 'test'

class LogsApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::LogsApi.new
  end

  def test_log_buffer
    get "/"
    assert_equal 3, JSON.parse(last_response.body)["info"]["level_tail"]
  end

  def test_log_buffer_timestamp
    get "/"
    t1 = JSON.parse(last_response.body)["logs"][0]["timestamp"]
    t2 = JSON.parse(last_response.body)["logs"][1]["timestamp"]
    assert t1 < t2
  end
end
