require 'bmc/base'

module Proxy
  module BMC
    class Shell < Base
      include Proxy::Log
      include Proxy::Util
      attr_accessor :kernel, :initram, :append

      def initialize(kernel, initram, append)
        @kernel = kernel
        @initram = initram
        @append = append
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
        if kernel && initram && append
          unless (kexec = which('kexec'))
            logger.warn "kexec binary was not found - aborting"
            return false
          end

          # download kernel and image synchronously
          if ::Proxy::HttpDownloads.start_download(kernel, '/tmp/vmlinuz').join != 0
            logger.warn "unable to download kernel - aborting"
            return false
          end
          if ::Proxy::HttpDownloads.start_download(initram, '/tmp/initrd.img').join != 0
            logger.warn "unable to download init RAM disk - aborting"
            return false
          end

          run_after_response 2, kexec, "--force", "--append='#{append}'", "--initrd=/tmp/initrd.img", "/tmp/vmlinuz"
        else
          unless (shutdown = which('shutdown'))
            logger.warn "shutdown binary was not found - aborting reboot"
            return false
          end

          run_after_response 5, shutdown, "-r", "now", "Foreman BMC API reboot"
        end

        # Because we are actually terminating the server, we do not care about the return code -
        # we actually must not care because there is no time to wait (we need to finish the request
        # as soon as possible).
        return true
      end

      private

      # Execute command in a separate thread after 5 seconds to give the server some time to finish
      # the request.
      def run_after_response(seconds, *command)
        logger.debug "BMC shell execution scheduled in #{seconds} seconds"
        Thread.start do
          begin
            sleep seconds
            logger.debug "BMC shell executing: #{command.inspect}"
            if (sudo = which('sudo'))
              status = system(sudo, *command)
            else
              logger.warn "sudo binary was not found"
            end
            # only report errors
            logger.warn "The attempted command failed with code #{$?.exitstatus}" unless status
          rescue Exception => e
            logger.error "Error during command execution: #{e}"
          end
        end
      end

    end
  end
end
