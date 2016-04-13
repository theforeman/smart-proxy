module ::Proxy::Puppet
  class Validators
    class UrlValidator < ::Proxy::PluginValidators::Base
      def validate!(settings)
        raise ::Proxy::Error::ConfigurationError, "Setting 'puppet_url' is expected to contain a url for puppet server" if settings[:puppet_url].to_s.empty?
        URI.parse(settings[:puppet_url])
      rescue URI::InvalidURIError
        raise ::Proxy::Error::ConfigurationError.new("Setting 'puppet_url' contains an invalid url for puppet server")
      end
    end
  end
end
