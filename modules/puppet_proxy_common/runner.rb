module Proxy::Puppet
  class Runner
    include Proxy::Log
    include Proxy::Util

    def shell_escaped_nodes(nodes)
      nodes.collect { |n| escape_for_shell(n) }
    end
  end
end
