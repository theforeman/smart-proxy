require "yaml"
require "ostruct"
require "pathname"

module Proxy::Settings
  extend ::Proxy::Log

  SETTINGS_PATH = Pathname.new(__dir__).join("..", "..", "config", "settings.yml")

  def self.initialize_global_settings(settings_path = nil, argv = ARGV)
    ::Proxy::Settings::Global.new(YAML.load(File.read(settings_path || SETTINGS_PATH)))
  end

  def self.load_plugin_settings(defaults, settings_file, settings_directory = nil)
    settings = {}
    begin
      settings = YAML.load(File.read(File.join(settings_directory || ::Proxy::SETTINGS.settings_directory, settings_file))) || {}
    rescue Errno::ENOENT
      logger.warn("Couldn't find settings file #{settings_directory || ::Proxy::SETTINGS.settings_directory}/#{settings_file}. Using default settings.")
    end
    ::Proxy::Settings::Plugin.new(defaults, settings)
  end

  def self.read_settings_file(settings_file, settings_directory = nil)
    YAML.load(File.read(File.join(settings_directory || ::Proxy::SETTINGS.settings_directory, settings_file))) || {}
  end
end
