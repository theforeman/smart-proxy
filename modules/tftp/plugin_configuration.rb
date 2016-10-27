module ::Proxy::TFTP
  class PluginConfiguration
    def load_classes
      require 'tftp/server'
      require 'tftp/http_downloads'
      require 'tftp/dependency_injection'
      require 'tftp/tftp_api'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.singleton_dependency :http_downloads, lambda {::Proxy::TFTP::HttpDownloads.new(settings[:tftproot])}
    end
  end
end
