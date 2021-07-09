require 'test_helper'
require File.join(__dir__, '../../extra/migrate_settings')
::Proxy::Migration.inject_migrations_instance(::Proxy::Migrations.new("dummy"))
require File.join(__dir__, '../../extra/migrations/20150327000000_migrate_monolithic_config')

class MonolithicConfigMigrationTest < Test::Unit::TestCase
  def setup
    @old_config = YAML.load_file(File.join(__dir__, './migration_settings.yml'))
    @output, @unknown = MigrateMonolithicConfig.new("/tmp").migrate_monolithic_config(@old_config)
  end

  def test_output_has_multiple_blocks
    assert_equal MigrateMonolithicConfig.new("/tmp").modules.size, @output.keys.size
  end

  def test_output_has_correct_general_settings
    assert_equal @output[:settings],
                 :ssl_ca_file     => "/var/lib/puppet/ssl/certs/ca.pem",
                 :ssl_certificate => "/var/lib/puppet/ssl/certs/foo.bar.example.com.pem",
                 :ssl_private_key => "/var/lib/puppet/ssl/private_keys/foo.bar.example.com.org.pem",
                 :trusted_hosts   => ["foreman.prod.domain", "foreman.dev.domain"],
                 :log_file        => "/var/log/foreman-proxy/proxy.log",
                 :log_level       => "DEBUG",
                 :https_port      => 8443,
                 :virsh_network   => "mynetwork"
  end

  def test_output_has_correct_tftp_settings
    assert_equal @output[:tftp],
                 :enabled         => true,
                 :tftproot        => "/srv/tftp",
                 :tftp_servername => "192.168.122.1"
  end

  def test_output_has_correct_dns_settings
    assert_equal @output[:dns],
                 :enabled    => true,
                 :dns_key    => "/etc/bind/rndc.key",
                 :dns_server => "127.0.0.1"
  end

  def test_output_has_correct_dhcp_settings
    assert_equal @output[:dhcp],
                 :enabled     => true,
                 :dhcp_vendor => "isc",
                 :dhcp_config => "/etc/dhcp3/dhcpd.conf",
                 :dhcp_leases => "/var/lib/dhcp3/dhcpd.leases"
  end

  def test_output_has_correct_puppet_settings
    assert_equal @output[:puppet],
                 :enabled     => true,
                 :puppet_conf => "/etc/puppet/puppet.conf"
  end

  def test_output_has_correct_puppetca_settings
    assert_equal @output[:puppetca],
                 :enabled   => true,
                 :ssldir    => "/var/lib/puppet/ssl",
                 :puppetdir => "/etc/puppet"
  end

  def test_output_has_correct_bmc_settings
    assert_equal @output[:bmc],
                 :enabled              => true,
                 :bmc_default_provider => "ipmitool"
  end

  def test_output_has_correct_chef_settings
    assert_equal @output[:chef],
                 :enabled                    => true,
                 :chef_authenticate_nodes    => true,
                 :chef_server_url            => "https://foreman.example.com",
                 :chef_smartproxy_clientname => "foreman_proxy",
                 :chef_smartproxy_privatekey => "/etc/chef/foreman_proxy.pem"
  end

  def test_output_has_correct_realm_settings
    assert_equal @output[:realm],
                 :enabled            => true,
                 :realm_provider     => "freeipa",
                 :realm_keytab       => "/etc/foreman-proxy/freeipa.keytab",
                 :realm_principal    => "realm-proxy@IPA.FM.EXAMPLE.NET",
                 :freeipa_remove_dns => true
  end

  def test_output_has_correct_unknown_settings
    assert_equal @unknown, :foo => "bar"
  end

  def test_migration_correctly_uses_http_when_ssl_disabled
    config = YAML.load_file(File.join(File.dirname(__FILE__), './migration_settings.yml'))
    config.delete(:ssl_certificate)
    output, _ = MigrateMonolithicConfig.new("/tmp").migrate_monolithic_config(config)
    assert_equal 8443, output[:settings][:http_port]
    assert_nil output[:settings][:https_port]
  end

  def test_migration_idempotence
    output2, _ = MigrateMonolithicConfig.new("/tmp").migrate_monolithic_config(@output[:settings].dup)
    # Matches the test used inside the script for its exit value
    assert_equal @output[:settings], output2[:settings]
  end
end
