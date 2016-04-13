module ::Proxy::PuppetSalt
  class PluginConfiguration
    def load_classes
      require 'puppet_proxy_common/runner'
      require 'puppet_proxy_salt/salt_main'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :puppet_runner_impl, (lambda do
        ::Proxy::PuppetSalt::Runner.new(settings[:command])
      end)
    end
  end
end
