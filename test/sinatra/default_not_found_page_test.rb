require 'test_helper'
require 'sinatra/base'
require 'sinatra/default_not_found_page'

class DefaultNotFoundPageTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    TestApp.new
  end

  def test_not_found_is_blank
    get "/unknown_url"
    assert_equal 'Requested url was not found', last_response.body
  end

  def test_not_found_returns_status_404
    get "/unknown_url"
    assert_equal 404, last_response.status
  end

  class TestApp < ::Sinatra::Base
  end
end
