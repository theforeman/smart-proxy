require "yaml"
require "ostruct"
require "pathname"
raw_config = File.read(Pathname.new(__FILE__).join("..", "..","..","config","settings.yml"))

class Settings < OpenStruct
  def method_missing args
    false
  end
end

settings = YAML.load(raw_config)
if RUBY_PLATFORM =~ /mingw/
  settings.delete :puppetca if settings.has_key? :puppetca
  settings.delete :puppet   if settings.has_key? :puppet
  settings[:x86_64] = File.exist?('c:\windows\sysnative\cmd.exe')
end
SETTINGS = Settings.new(settings)
