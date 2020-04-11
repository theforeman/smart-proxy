require 'test_helper'
require 'puppetca/puppetca'
require 'puppetca/dependency_injection'
require 'puppetca_http_api/puppetca_impl'

class PuppetCaHttpImplTest < Test::Unit::TestCase
  class FakeCaApiV1Request
    def sign(certname)
    end

    def clean(certname)
    end

    def search(key = 'foreman')
      [
        {
          'name' => 'puppet.example.com',
          'state' => 'signed',
          'dns_alt_names' => ['DNS:puppet', 'DNS:puppet.example.com'],
          'subject_alt_names' => ['DNS:puppet', 'DNS:puppet.example.com'],
          'fingerprint' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
          'fingerprints' => {
            'SHA1' => '4F:C2:4B:C5:B3:AD:36:64:8D:70:65:85:0B:F9:29:9E:96:67:4B:6F',
            'SHA256' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
            'SHA512' => '83:BD:D2:32:30:F3:3E:69:7D:61:ED:A8:3F:3D:29:81:1C:96:AC:39:9B:A3:09:9E:61:9F:17:78:91:69:73:12:84:51:59:EE:93:42:AB:A8:34:72:41:43:B5:48:32:E7:3C:DE:85:13:5E:78:A5:C9:FD:A3:FF:54:53:7C:E6:03',
            'default' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
          },
        },
      ]
    end
  end

  class FakeCaApiV1Request63 < FakeCaApiV1Request
    def search(key = 'foreman')
      [
        {
          'name' => 'puppet.example.com',
          'state' => 'signed',
          'dns_alt_names' => ['DNS:puppet', 'DNS:puppet.example.com'],
          'subject_alt_names' => ['DNS:puppet', 'DNS:puppet.example.com'],
          'fingerprint' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
          'fingerprints' => {
            'SHA1' => '4F:C2:4B:C5:B3:AD:36:64:8D:70:65:85:0B:F9:29:9E:96:67:4B:6F',
            'SHA256' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
            'SHA512' => '83:BD:D2:32:30:F3:3E:69:7D:61:ED:A8:3F:3D:29:81:1C:96:AC:39:9B:A3:09:9E:61:9F:17:78:91:69:73:12:84:51:59:EE:93:42:AB:A8:34:72:41:43:B5:48:32:E7:3C:DE:85:13:5E:78:A5:C9:FD:A3:FF:54:53:7C:E6:03',
            'default' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
          },
          'not_after' => '2039-08-25T19:25:29UTC',
          'not_before' => '2014-08-25T19:25:29UTC',
          'serial_number' => 4,
        },
      ]
    end
  end

  class FakeCaApiV1Request63Expired < FakeCaApiV1Request
    def search(key = 'foreman')
      [
        {
          'name' => 'puppet.example.com',
          'state' => 'signed',
          'dns_alt_names' => ['DNS:puppet', 'DNS:puppet.example.com'],
          'subject_alt_names' => ['DNS:puppet', 'DNS:puppet.example.com'],
          'fingerprint' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
          'fingerprints' => {
            'SHA1' => '4F:C2:4B:C5:B3:AD:36:64:8D:70:65:85:0B:F9:29:9E:96:67:4B:6F',
            'SHA256' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
            'SHA512' => '83:BD:D2:32:30:F3:3E:69:7D:61:ED:A8:3F:3D:29:81:1C:96:AC:39:9B:A3:09:9E:61:9F:17:78:91:69:73:12:84:51:59:EE:93:42:AB:A8:34:72:41:43:B5:48:32:E7:3C:DE:85:13:5E:78:A5:C9:FD:A3:FF:54:53:7C:E6:03',
            'default' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
          },
          'not_after' => '2018-08-25T19:25:29UTC',
          'not_before' => '2014-08-25T19:25:29UTC',
          'serial_number' => 4,
        },
      ]
    end
  end

  def setup
    @api = Proxy::PuppetCa::PuppetcaHttpApi::PuppetcaImpl.new
    client = FakeCaApiV1Request.new
    @api.stubs(:client).returns(client)
  end

  def test_sign
    assert_nil @api.sign('puppet.example.com')
  end

  def test_clean
    assert_nil @api.clean('puppet.example.com')
  end

  def test_list
    expected = {
      'puppet.example.com' => {
        'fingerprint' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
        'not_after' => nil,
        'not_before' => nil,
        'serial' => nil,
        'state' => 'valid',
      },
    }

    assert_equal expected, @api.list
  end

  def test_list_puppetserver_6_3
    client = FakeCaApiV1Request63.new
    @api.stubs(:client).returns(client)

    expected = {
      'puppet.example.com' => {
        'fingerprint' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
        'not_after' => '2039-08-25T19:25:29UTC',
        'not_before' => '2014-08-25T19:25:29UTC',
        'serial' => 4,
        'state' => 'valid',
      },
    }

    assert_equal expected, @api.list
  end

  def test_list_puppetserver_6_3_expired_cert
    client = FakeCaApiV1Request63Expired.new
    @api.stubs(:client).returns(client)

    expected = {
      'puppet.example.com' => {
        'fingerprint' => 'F8:DA:15:EA:BD:2F:2D:D3:05:71:73:55:96:74:A4:97:2B:04:06:47:A8:8E:D2:C4:AB:8F:EC:3B:7C:0F:0A:EE',
        'not_after' => '2018-08-25T19:25:29UTC',
        'not_before' => '2014-08-25T19:25:29UTC',
        'serial' => 4,
        'state' => 'revoked',
      },
    }

    assert_equal expected, @api.list
  end
end
