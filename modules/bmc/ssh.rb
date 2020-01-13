module Proxy
  module BMC
    class SSH < Base
      include Proxy::Log
      include Proxy::Util

      attr_reader :host

      def initialize(host)
        @host = host
        @ssh_user = Proxy::BMC::Plugin.settings.bmc_ssh_user || 'root'
        @ssh_key = Proxy::BMC::Plugin.settings.bmc_ssh_key
        @poweron = Proxy::BMC::Plugin.settings.bmc_ssh_poweron || 'false'
        @poweroff = Proxy::BMC::Plugin.settings.bmc_ssh_poweroff || 'shutdown +1'
        @powerstatus = Proxy::BMC::Plugin.settings.bmc_ssh_powerstatus || 'true'
        @powercycle = Proxy::BMC::Plugin.settings.bmc_ssh_powercycle || 'shutdown -r +1'
      end

      # call remote command and return bool
      def ssh(command)
        unless (ssh_binary = which('ssh'))
          logger.warn 'Unable to locate ssh binary'
          return false
        end
        cmd = []
        cmd.push(ssh_binary)
        if (file = @ssh_key)
          if File.exist?(file)
            cmd.push("-i", file)
          else
            logger.warn("Unable to access SSH private key: #{file}, ignoring...")
          end
        end
        cmd.push("-o", "ConnectTimeout=2")
        cmd.push(@ssh_user + '@' + host)
        cmd.push(command)
        shell_command(cmd)
      end

      def self.installed?
        File.exist?(@ssh_key)
      end

      def poweron(soft = false)
        ssh(@poweron)
      end

      def poweroff(soft = false)
        ssh(@poweroff)
      end

      def powerstatus
        if ssh(@powerstatus)
          'on'
        else
          'off'
        end
      end

      def powercycle
        ssh(@powercycle)
      end

      def ip
        host
      end

      # the following are dummy implementations

      def mac
        ''
      end

      def gateway
        ''
      end

      def netmask
        ''
      end

      def bootpxe(reboot=false, persistent=false)
      end

      def bootdisk(reboot=false, persistent=false)
      end

      def bootbios(reboot=false, persistent=false)
      end

      def bootcdrom(reboot=false, persistent=false)
      end
    end
  end
end
