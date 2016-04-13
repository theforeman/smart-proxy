module ::Proxy::PuppetSsh
  class PluginConfiguration
    def load_classes
      require 'puppet_proxy_common/runner'
      require 'puppet_proxy_ssh/puppet_proxy_ssh_main'
    end

    def load_dependency_injection_wirings(container_instance, settings)
      container_instance.dependency :puppet_runner_impl, (lambda do
        ::Proxy::PuppetSsh::Runner.new(settings[:command], settings[:user], settings[:keyfile], settings[:use_sudo], settings[:wait])
      end)
    end
  end
end
