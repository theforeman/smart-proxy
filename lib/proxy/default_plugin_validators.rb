class Proxy::DefaultPluginValidators
  def self.validators
    {:file_readable => ::Proxy::PluginValidators::FileReadable, :presence => ::Proxy::PluginValidators::Presence}
  end
end
