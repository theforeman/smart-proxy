require 'test_helper'
require File.join(File.dirname(__FILE__),'../extra/migrate_dns_settings')

class ProxyDnsMigrationTest < Test::Unit::TestCase

  def setup
    @old_config = YAML.load_file(File.join(File.dirname(__FILE__),'./migration_dns_settings.yml'))
    @output, @unknown = migrate_dns_configuration(@old_config.dup)
  end

  def test_migrate_dns_provider_name
    assert_equal 'dns_nsupdate', migrate_dns_provider_name('nsupdate')
    assert_equal 'dns_nsupdate_gss', migrate_dns_provider_name('nsupdate_gss')
    assert_equal 'dns_dnscmd', migrate_dns_provider_name('dnscmd')
    assert_equal 'dns_virsh', migrate_dns_provider_name('virsh')
    assert_equal 'blah', migrate_dns_provider_name('blah')
  end

  def test_output_has_correct_dns_settings
    assert_equal @output[:dns],
                 :dns_provider => "dns_nsupdate",
                 :enabled => true
  end

  def test_output_has_correct_nsupdate_settings
    assert_equal @output[:dns_nsupdate],
                 :dns_key => "/etc/bind/rndc.key",
                 :dns_server => "127.0.0.1",
                 :dns_ttl => 86_400
  end

  def test_output_has_correct_nsupdate_gss_settings
    assert_equal @output[:dns_nsupdate_gss],
                 :dns_key => "/etc/bind/rndc.key",
                 :dns_server => "127.0.0.1",
                 :dns_ttl => 86_400,
                 :dns_tsig_keytab => "/usr/share/foreman-proxy/dns.keytab",
                 :dns_tsig_principal => "DNS/host.example.com@EXAMPLE.COM"
  end

  def test_output_has_correct_dnscmd_settings
    assert_equal @output[:dns_dnscmd],
                 :dns_server => "127.0.0.1"
  end

  def test_output_should_be_saved
    assert should_save?(@old_config, @output)
  end
end
