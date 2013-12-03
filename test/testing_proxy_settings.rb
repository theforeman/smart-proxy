require "proxy/settings"

class Settings < OpenStruct
  module TestingSettings
    DEFAULTS = { :tftp => true,
                        :puppet => true,
                        :puppetca => true,
                        :bmc => true,
                        :dhcp => true,
                        :dhcp_vendor => 'isc',
                        :dhcp_config => './test/dhcp.conf',
                        :dhcp_leases => './test/dhcp.leases',
                        :dhcp_subnets => ['192.168.122.0/255'],
                        :puppet_conf => File.join(File.dirname(__FILE__), 'fixtures', 'puppet.conf'),
                        :log_file => File.join('logs', 'test.log') }
  end
  DEFAULTS.merge!(TestingSettings::DEFAULTS)

  def self.load_from_file(settings_path = nil)
    load({})
  end
end
