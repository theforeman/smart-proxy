module ::Proxy::PuppetCustomrun
  class PluginConfiguration
    def load_classes
      require 'puppet_proxy_common/runner'
      require 'puppet_proxy_customrun/customrun_main'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :puppet_runner_impl, (lambda do
        ::Proxy::PuppetCustomrun::Runner.new(settings[:command], settings[:command_arguments])
      end)
    end
  end
end
