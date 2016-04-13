module ::Proxy::PuppetMCollective
  class PluginConfiguration
    def load_classes
      require 'puppet_proxy_common/runner'
      require 'puppet_proxy_mcollective/mcollective_main'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :puppet_runner_impl, (lambda do
        ::Proxy::PuppetMCollective::Runner.new(settings[:user])
      end)
    end
  end
end
