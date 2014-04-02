require 'bmc/base'

module Proxy
  module BMC
    class Shell < Base
      include Proxy::Log
      include Proxy::Util

      def initialize
        # Nothing needed to set up shell
      end

      def self.installed?(args)
        return true # We can always shell out
      end

      # Must be on
      def poweron?
        true
      end

      # Must be on
      def poweroff?
        false
      end

      # Must be on
      def powerstatus
        "on"
      end

      def powercycle
        # search for sudo
        sudo = which("sudo")

        unless sudo
          logger.warn "sudo binary was not found - aborting"
          return false
        end

        cycle_cmd = [sudo,"shutdown","-r","now","foreman_proxy initiated shutdown via BMC shell api"]

        # Returns a boolean with whether or not the command executed successfully.
        stdout = `#{cycle_cmd.join(' ')}`
        if $? == 0
          logger.info "Shutdown command successful"
          return true
        else
          logger.warn "The attempted shutdown failed: \n#{stdout}"
          return false
        end
      end

    end
  end
end
