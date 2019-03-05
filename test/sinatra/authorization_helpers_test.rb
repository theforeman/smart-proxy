require 'test_helper'
require 'sinatra/base'

class AuthorizationHelpersTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    TestApp.new
  end

  def test_http
    get '/public'
    assert last_response.ok?
    get '/private'
    assert last_response.ok?
  end

  def test_https
    get '/public', {}, 'HTTPS' => 'yes'
    assert last_response.ok?
    get '/private', {}, 'HTTPS' => 'yes'
    assert last_response.forbidden?
  end

  class TestApp < ::Sinatra::Base
    include Sinatra::Authorization::Helpers

    get '/public' do
      'success'
    end

    get '/private' do
      do_authorize_any
      'success'
    end
  end
end
