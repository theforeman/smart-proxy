require 'test_helper'
require File.join(File.dirname(__FILE__),'../../extra/migrate_settings')
::Proxy::Migration.inject_migrations_instance(::Proxy::Migrations.new("dummy"))
require File.join(File.dirname(__FILE__),'../../extra/migrations/20150611000000_migrate_dns_settings')

class ProxyDnsMigrationTest < Test::Unit::TestCase

  def setup
    @old_config = YAML.load_file(File.join(File.dirname(__FILE__),'./migration_dns_settings.yml'))
    @migration = MigrateDnsSettings.new("/tmp")
    @output, @unknown = @migration.migrate_dns_configuration(@old_config.dup)
  end

  def test_migrate_dns_provider_name
    assert_equal 'dns_nsupdate', @migration.migrate_dns_provider_name('nsupdate')
    assert_equal 'dns_nsupdate_gss', @migration.migrate_dns_provider_name('nsupdate_gss')
    assert_equal 'dns_dnscmd', @migration.migrate_dns_provider_name('dnscmd')
    assert_equal 'dns_virsh', @migration.migrate_dns_provider_name('virsh')
    assert_equal 'blah', @migration.migrate_dns_provider_name('blah')
  end

  def test_output_has_correct_dns_settings
    assert_equal @output[:dns],
                 :use_provider => "dns_nsupdate",
                 :dns_ttl => 86_400,
                 :enabled => true
  end

  def test_output_has_correct_nsupdate_settings
    assert_equal @output[:dns_nsupdate],
                 :dns_key => "/etc/bind/rndc.key",
                 :dns_server => "127.0.0.1"
  end

  def test_output_has_correct_nsupdate_gss_settings
    assert_equal @output[:dns_nsupdate_gss],
                 :dns_server => "127.0.0.1",
                 :dns_tsig_keytab => "/usr/share/foreman-proxy/dns.keytab",
                 :dns_tsig_principal => "DNS/host.example.com@EXAMPLE.COM"
  end

  def test_output_has_correct_dnscmd_settings
    assert_equal @output[:dns_dnscmd],
                 :dns_server => "127.0.0.1"
  end
end
