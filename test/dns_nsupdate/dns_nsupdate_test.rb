require 'test_helper'
require 'dns/dns'
require 'dns_nsupdate/dns_nsupdate_plugin'
require 'dns_nsupdate/dns_nsupdate_main'

class DnsNsupdateTest < Test::Unit::TestCase
  def test_nsupdate_entry_not_exist_returns_proxy_dns_notfound
    Proxy::Dns::Nsupdate::Plugin.settings.stubs(:dns_key).returns(nil)
    Proxy::Dns::Nsupdate::Record.any_instance.stubs(:nsupdate).returns(true)
    Resolv::DNS.any_instance.stubs(:getaddress).raises(Resolv::ResolvError.new('DNS result has no information'))
    Resolv::DNS.any_instance.stubs(:getaname).raises(Resolv::ResolvError.new('DNS result has no information'))
    server = Proxy::Dns::Nsupdate::Record.new(:fqdn => 'not_existing.example.com')
    assert_raise Proxy::Dns::NotFound do
      server.remove
    end
  end

  def test_nsupdate_removes_existing_entry
    Proxy::Dns::Nsupdate::Plugin.settings.stubs(:dns_key).returns(nil)
    Proxy::Dns::Nsupdate::Record.any_instance.stubs(:nsupdate).returns(true)
    Resolv::DNS.any_instance.stubs(:getaddress).returns('127.13.0.2')
    Resolv::DNS.any_instance.stubs(:getaname).returns('not_existing.example.com')
    server = Proxy::Dns::Nsupdate::Record.new(:fqdn => 'not_existing.example.com')
    assert server.remove
  end
end
