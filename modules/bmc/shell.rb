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

      # test to ensure connection is valid
      # since we assume shell will always work we just return, but we could later
      # test for correct sudo access to shutdown to ensure correct behavior
      def test
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
        sudo = which('sudo')
        shutdown = which('shutdown')

        unless sudo
          logger.warn "sudo binary was not found - aborting reboot"
          return false
        end

        unless shutdown
          logger.warn "shutdown binary was not found - aborting reboot"
          return false
        end

        # because we are actually terminating the server, we do not care about the return code -
        # we actually must not care because there is no time to wait (we need to finish the request
        # as soon as possible)
        Thread.start do
          # give the http server some time to flush the buffers
          sleep 5
          # and see you next time
          exitcode = system sudo, "shutdown", "-r", "now", "Foreman BMC API"
          # only report errors
          if exitcode != 0
            logger.warn "The attempted shutdown failed with code #{exitcode}"
          end
        end

        # let's return true and finish the request
        return true
      end

    end
  end
end
