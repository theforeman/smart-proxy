require 'test_helper'
require 'json'
require 'sinatra/base'

ENV['RACK_ENV'] = 'test'

class SSLClientVerificationTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    TestApp.new
  end

  def test_http
    get '/test'
    assert last_response.ok?
  end

  ['yes', 'on', '1', 'https'].each do |yes|
    define_method("test_https_no_cert_https_#{yes}") do
      get '/test', {}, 'HTTPS' => yes
      assert last_response.forbidden?
    end
  end

  def test_https_cert_webrick
    get '/test', {}, 'HTTPS' => 'yes', 'SSL_CLIENT_CERT' => '...'
    assert last_response.ok?
  end

  def test_https_cert_puma
    get '/test', {}, 'HTTPS' => 'https', 'puma.peercert' => '...'
    assert last_response.ok?
  end

  class TestApp < ::Sinatra::Base
    authorize_with_ssl_client

    get '/test' do
      'success'
    end
  end
end
