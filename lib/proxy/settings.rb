require "yaml"
require "ostruct"
puts File.dirname(__FILE__)
raw_config = File.read("#{File.dirname(__FILE__)}/../../config/settings.yml")

class Settings < OpenStruct
  def method_missing args
    false
  end
end

SETTINGS = Settings.new(YAML.load(raw_config))
