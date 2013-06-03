require "proxy/settings"

class Settings < OpenStruct
  module TestingSettings
    DEFAULTS = { :tftp => true,
                        :puppet => true,
                        :puppetca => true,
                        :bmc => true,
                        :puppet_conf => File.join(File.dirname(__FILE__), 'fixtures', 'puppet.conf'),
                        :log_file => File.join('logs', 'test.log') }
  end
  DEFAULTS.merge!(TestingSettings::DEFAULTS)

  def self.load_from_file(settings_path = nil)
    load({})
  end
end
