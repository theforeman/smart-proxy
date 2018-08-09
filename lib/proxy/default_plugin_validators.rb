class Proxy::DefaultPluginValidators
  def self.validators
    {
      :file_readable => ::Proxy::PluginValidators::FileReadable,
      :presence => ::Proxy::PluginValidators::Presence,
      :presence_allow_empty => ::Proxy::PluginValidators::PresenceAllowEmpty,
    }
  end
end
