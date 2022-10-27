class Proxy::DefaultPluginValidators
  def self.validators
    {
      file_readable: ::Proxy::PluginValidators::FileReadable,
      presence: ::Proxy::PluginValidators::Presence,
      url: ::Proxy::PluginValidators::Url,
      optional_url: ::Proxy::PluginValidators::OptionalUrl,
      boolean: ::Proxy::PluginValidators::Boolean,
      enum: ::Proxy::PluginValidators::Enum,
    }
  end
end
