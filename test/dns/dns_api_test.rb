require 'test_helper'
require 'dns_common/dependency_injection/container'
require 'dns/dns_api'


ENV['RACK_ENV'] = 'test'

class DnsApiTest < Test::Unit::TestCase
  class DnsApiTestProvider
    attr_reader :fqdn, :ip, :type
    def create_a_record(fqdn, ip)
      @fqdn = fqdn; @ip = ip; @type = 'A'
    end
    def create_ptr_record(fqdn, ip)
      @fqdn = fqdn; @ip = ip; @type = 'PTR'
    end
    def remove_a_record(fqdn)
      @fqdn = fqdn; @type = 'A'
    end
    def remove_ptr_record(ip)
      @ip = ip; @type = 'PTR'
    end
  end

  include Rack::Test::Methods

  def app
    app = Proxy::Dns::Api.new
    @server = DnsApiTestProvider.new
    app.helpers.server = @server
    app
  end

  def test_create_a_record
    post '/', :fqdn => 'test.com', :value => '192.168.33.33', :type => 'A'
    assert_equal 'test.com', @server.fqdn
    assert_equal '192.168.33.33', @server.ip
    assert_equal 'A', @server.type
  end

  def test_create_returns_error_if_fqdn_is_missing
    post '/', :value => '192.168.33.33', :type => 'A'
    assert_equal 400, last_response.status
  end

  def test_create_returns_error_if_ip_is_missing
    post '/', :fqdn => 'test.com', :type => 'A'
    assert_equal 400, last_response.status
  end

  def test_create_returns_error_if_type_is_missing
    post '/', :fqdn => 'test.com', :value => '192.168.33.33'
    assert_equal 400, last_response.status
  end

  def test_create_returns_error_if_type_is_unrecognized
    post '/', :fqdn => 'test.com', :value => '192.168.33.33', :type => "FFF"
    assert_equal 400, last_response.status
  end

  def test_create_ptr_record
    post '/', :fqdn => 'test.com', :value => '192.168.33.33', :type => 'PTR'
    assert_equal 'test.com', @server.fqdn
    assert_equal '192.168.33.33', @server.ip
    assert_equal 'PTR', @server.type
  end

  def test_delete_a_record
    delete '/test.com'
    assert_equal 'test.com', @server.fqdn
    assert_equal 'A', @server.type
  end

  def test_delete_ptr_record
    delete '/33.33.168.192.in-addr.arpa'
    assert_equal '33.33.168.192.in-addr.arpa', @server.ip
    assert_equal 'PTR', @server.type
  end

  def test_delete_returns_error_if_value_is_missing
    delete '/'
    assert_equal 404, last_response.status
  end
end
