module ::Proxy::PuppetRun
  class PluginConfiguration
    def load_classes
      require 'puppet_proxy_common/runner'
      require 'puppet_proxy_puppetrun/puppetrun_main'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :puppet_runner_impl, (lambda do
        ::Proxy::PuppetRun::Runner.new(settings[:user])
      end)
    end
  end
end
