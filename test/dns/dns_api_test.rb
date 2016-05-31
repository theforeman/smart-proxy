require 'test_helper'
require 'dns_common/dependency_injection/container'
require 'dns/dns_api'


ENV['RACK_ENV'] = 'test'

class DnsApiTest < Test::Unit::TestCase
  class DnsApiTestProvider
    attr_reader :fqdn, :ip, :type, :target
    def create_a_record(fqdn, ip)
      @fqdn = fqdn; @ip = ip; @type = 'A'
    end
    def create_aaaa_record(fqdn, ip)
      @fqdn = fqdn; @ip = ip; @type = 'AAAA'
    end
    def create_ptr_record(fqdn, ip)
      @fqdn = fqdn; @ip = ip; @type = 'PTR'
    end
    def create_cname_record(fqdn, target)
      @fqdn = fqdn; @target = target; @type = 'CNAME'
    end
    def remove_a_record(fqdn)
      @fqdn = fqdn; @type = 'A'
    end
    def remove_aaaa_record(fqdn)
      @fqdn = fqdn; @type = 'AAAA'
    end
    def remove_ptr_record(ip)
      @ip = ip; @type = 'PTR'
    end
    def remove_cname_record(fqdn)
      @fqdn = fqdn; @type = 'CNAME'
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
    assert_equal 200, last_response.status
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

  def test_create_returns_error_if_invalid_name_for_a
    post '/', :fqdn => '-test.com', :value => '33.33.168.192.in-addr.arpa', :type => 'A'
    assert_equal 400, last_response.status
  end

  def test_create_returns_error_if_invalid_name_for_ptr
    post '/', :fqdn => '-test.com', :value => '33.33.168.192.in-addr.arpa', :type => 'PTR'
    assert_equal 400, last_response.status
  end

  def test_create_returns_error_if_invalid_ip_for_a
    post '/', :fqdn => 'test.com', :value => '300.1.1.1', :type => 'A'
    assert_equal 400, last_response.status
  end

  def test_create_returns_error_if_ipv6_for_a
    post '/', :fqdn => 'test.com', :value => '2001:db8::1', :type => 'A'
    assert_equal 400, last_response.status
  end

  def test_create_returns_error_if_invalid_reverse_dns
    post '/', :fqdn => 'test.com', :value => '192.168.33.33', :type => 'PTR'
    assert_equal 400, last_response.status
  end

  def test_create_returns_error_on_ipv4_for_aaaa
    post '/', :fqdn => 'test.com', :value => '192.168.1.2', :type => "AAAA"
    assert_equal 400, last_response.status
  end

  def test_create_returns_error_on_invalid_ipv6_for_aaaa
    post '/', :fqdn => 'test.com', :value => 'xxxx::1', :type => "AAAA"
    assert_equal 400, last_response.status
  end

  def test_create_ptr_v4_record
    post '/', :fqdn => 'test.com', :value => '33.33.168.192.in-addr.arpa', :type => 'PTR'
    assert_equal 200, last_response.status
    assert_equal 'test.com', @server.fqdn
    assert_equal '33.33.168.192.in-addr.arpa', @server.ip
    assert_equal 'PTR', @server.type
  end

  def test_create_ptr_v6_record
    post '/', :fqdn => 'test.com', :value => '1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa', :type => 'PTR'
    assert_equal 200, last_response.status
    assert_equal 'test.com', @server.fqdn
    assert_equal '1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa', @server.ip
    assert_equal 'PTR', @server.type
  end

  def test_create_aaaa_record
    post '/', :fqdn => 'test.com', :value => '2001:db8::1', :type => 'AAAA'
    assert_equal 200, last_response.status
    assert_equal 'test.com', @server.fqdn
    assert_equal '2001:db8::1', @server.ip
    assert_equal 'AAAA', @server.type
  end

  def test_create_aaaa_record_is_shortened
    post '/', :fqdn => 'test.com', :value => '2001:0db8:0000:0000:0000:0000:0000:0001', :type => 'AAAA'
    assert_equal 200, last_response.status
    assert_equal 'test.com', @server.fqdn
    assert_equal '2001:db8::1', @server.ip
    assert_equal 'AAAA', @server.type
  end

  def test_create_cname_record
    post '/', :fqdn => 'test.com', :value => 'test1.com', :type => 'CNAME'
    assert_equal 200, last_response.status
    assert_equal 'test.com', @server.fqdn
    assert_equal 'test1.com', @server.target
    assert_equal 'CNAME', @server.type
  end

  def test_delete_a_record
    delete '/test.com'
    assert_equal 200, last_response.status
    assert_equal 'test.com', @server.fqdn
    assert_equal 'A', @server.type
  end

  def test_delete_explicit_a_record
    delete "/test.com/A"
    assert_equal 200, last_response.status
    assert_equal 'test.com', @server.fqdn
    assert_equal 'A', @server.type
  end

  def test_delete_ptr_record
    delete '/33.33.168.192.in-addr.arpa'
    assert_equal 200, last_response.status
    assert_equal '33.33.168.192.in-addr.arpa', @server.ip
    assert_equal 'PTR', @server.type
  end

  def test_delete_explicit_ptr_record
    delete '/33.33.168.192.in-addr.arpa/PTR'
    assert_equal 200, last_response.status
    assert_equal '33.33.168.192.in-addr.arpa', @server.ip
    assert_equal 'PTR', @server.type
  end

  def test_delete_aaaa_record
    delete "/test.com/AAAA"
    assert_equal 200, last_response.status
    assert_equal 'test.com', @server.fqdn
    assert_equal 'AAAA', @server.type
  end

  def test_delete_explicit_cname_record
    delete "/test.com/CNAME"
    assert_equal 200, last_response.status
    assert_equal 'test.com', @server.fqdn
    assert_equal 'CNAME', @server.type
  end

  def test_delete_returns_error_if_value_is_missing
    delete '/'
    assert_equal 404, last_response.status
  end

  def test_delete_returns_error_on_invalid_name
    delete '/-domain'
    assert_equal 400, last_response.status
  end

  def test_delete_returns_error_on_invalid_reverse_dns
    delete '/test.com/PTR'
    assert_equal 400, last_response.status
  end

  def test_delete_returns_error_on_invalid_type
    delete "/test.com/INVALID"
    assert_equal 400, last_response.status
  end
end
