require "yaml"
puts File.dirname(__FILE__)
raw_config = File.read("#{File.dirname(__FILE__)}/../../config/settings.yml")
SETTINGS = YAML.load(raw_config)
