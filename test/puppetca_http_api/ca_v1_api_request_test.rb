require 'test_helper'
require 'puppetca_http_api/puppetca_http_api'
require 'puppetca_http_api/ca_v1_api_request'

class CaApiv1RequestTest < Test::Unit::TestCase
  def setup
    @client = Proxy::PuppetCa::PuppetcaHttpApi::CaApiv1Request.new('https://puppet:8140/', nil, nil, nil)
  end

  def test_sign
    stub_request(:put, 'https://puppet:8140/puppet-ca/v1/certificate_status/puppet.example.com').
      with(:body => "{\"desired_state\":\"signed\"}").
      to_return(:status => 204)

    assert_nil @client.sign('puppet.example.com')
  end

  def test_clean
    stub_request(:put, 'https://puppet:8140/puppet-ca/v1/certificate_status/puppet.example.com').
      with(:body => "{\"desired_state\":\"revoked\"}").
      to_return(:status => 204)

    stub_request(:delete, 'https://puppet:8140/puppet-ca/v1/certificate_status/puppet.example.com').
      to_return(:status => 204)

    assert_nil @client.clean('puppet.example.com')
  end

  def test_clean_with_cleaned_certs
    stub_request(:put, 'https://puppet:8140/puppet-ca/v1/certificate_status/puppet.example.com').
      with(:body => "{\"desired_state\":\"revoked\"}").
      to_return(:status => 404, :body => 'Invalid certificate subject.')

    stub_request(:delete, 'https://puppet:8140/puppet-ca/v1/certificate_status/puppet.example.com').
      to_return(:status => 404, :body => 'Resource not found.')

    assert_nil @client.clean('puppet.example.com')
  end

  def test_clean_with_certs_in_requested_state
    stub_request(:put, 'https://puppet:8140/puppet-ca/v1/certificate_status/puppet.example.com').
      with(:body => "{\"desired_state\":\"revoked\"}").
      to_return(:status => 409, :body => 'Cannot revoke certificate for host puppet.example.com without a signed certificate')

    stub_request(:delete, 'https://puppet:8140/puppet-ca/v1/certificate_status/puppet.example.com').
      to_return(:status => 204)

    assert_nil @client.clean('puppet.example.com')
  end

  def test_search
    stub_request(:get, 'https://puppet:8140/puppet-ca/v1/certificate_statuses/foreman').
      to_return(:status => 200, :body => fixture('ca_search.json'))

    expected = [
      {
        'dns_alt_names' => ['DNS:puppet', 'DNS:puppet.example.com'],
        'fingerprint' =>
        'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
          'fingerprints' =>
        {
          'SHA1' => '4F:C2:4B:C5:B3:AD:36:64:8D:70:65:85:0B:F9:29:9E:96:67:4B:6F',
          'SHA256' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
          'SHA512' =>
          '83:BD:D2:32:30:F3:3E:69:7D:61:ED:A8:3F:3D:29:81:1C:96:AC:39:9B:A3:09:9E:61:9F:17:78:91:69:73:12:84:51:59:EE:93:42:AB:A8:34:72:41:43:B5:48:32:E7:3C:DE:85:13:5E:78:A5:C9:FD:A3:FF:54:53:7C:E6:03',
            'default' =>
          'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
        },
        'name' => 'puppet.example.com',
        'state' => 'signed',
        'subject_alt_names' => ['DNS:puppet', 'DNS:puppet.example.com'],
      },
    ]

    assert_equal expected, @client.search
  end

  def fixture(file)
    File.open(File.expand_path(File.join(File.dirname(__FILE__), '.', 'fixtures', file)))
  end
end
