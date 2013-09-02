require "proxy/settings"

class Settings < OpenStruct
  module TestingSettings
    DEFAULTS = { :tftp        => true,
                 :bmc         => true,
                 :puppet      => true,
                 :puppetca    => true,
                 :puppet_conf => File.join(File.dirname(__FILE__), 'fixtures', 'puppet.conf'),
                 :log_file    => File.join('logs', 'test.log'),
                 :templates   => true,
                 :foreman_url => 'http://127.0.0.1:3000'
    }
  end
  DEFAULTS.merge!(TestingSettings::DEFAULTS)

  def self.load_from_file(settings_path = nil)
    load({})
  end
end
