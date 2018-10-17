require 'test_helper'
require 'puppetca/plugin_configuration'
require 'puppetca/puppetca_plugin'

ENV['RACK_ENV'] = 'test'

class TestAutosigner

end

class TestPuppetcaImpl
  def list
    {}
  end

  def sign(certname); end
  def clean(certname); end
end


module Proxy::PuppetCa
  module DependencyInjection
    include Proxy::DependencyInjection::Accessors
    def container_instance
      Proxy::DependencyInjection::Container.new do |c|
        c.dependency :puppetca_impl, lambda { TestPuppetcaImpl.new }
        c.dependency :autosigner, lambda { TestAutosigner.new }
      end
    end
  end
end

require 'puppetca/puppetca_api'

class PuppetcaApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::PuppetCa::Api.new
  end

  def test_lists_certificates
    get '/'
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    assert_equal({}, JSON.parse(last_response.body))
  end

  def test_signs_certificates
    post '/puppet.example.com'
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    assert_equal '', last_response.body
  end

  def test_cleans_certificates
    delete '/puppet.example.com'
    assert last_response.ok?, "Last response was not ok: #{last_response.status} #{last_response.body}"
    assert_equal '', last_response.body
  end
end
