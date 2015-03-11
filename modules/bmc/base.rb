module Proxy
  module BMC
    class Base

      # This is the base class for bmc control.  Treat this class as an interface
      def initialize(args)
        @host = connect(args)
      end

      def poweroff(soft=false)
        raise NotImplementedError.new
      end

      def poweron
        raise NotImplementedError.new
      end

      def poweron?
        raise NotImplementedError.new
      end

      def poweroff?
        raise NotImplementedError.new
      end

      def self.installed?
        raise NotImplementedError.new
      end

      def self.providers
        raise NotImplementedError.new
      end

      def self.providers_installed?
        raise NotImplementedError.new
      end

      def powerstatus
        raise NotImplementedError.new
      end

      def identifystatus
        raise NotImplementedError.new
      end

      def powercycle
        raise NotImplementedError.new
      end

      def bootdevice
        raise NotImplementedError.new
      end

      def bootdevices
        raise NotImplementedError.new
      end

      def bootdevice=(args={ :device => nil, :reboot => false, :persistent => false })
        raise NotImplementedError.new
      end

      def identifyon
        raise NotImplementedError.new
      end

      def identifyoff
        raise NotImplementedError.new
      end

      def bootpxe(reboot=false, persistent=false)
        raise NotImplementedError.new
      end

      def bootdisk(reboot=false, persistent=false)
        raise NotImplementedError.new
      end

      def bootbios(reboot=false, persistent=false)
        raise NotImplementedError.new
      end

      def bootcdrom(reboot=false, persistent=false)
        raise NotImplementedError.new
      end

      # return the ip of the bmc device
      def ip
        raise NotImplementedError.new
      end

      # return the mac of the bmc device
      def mac
        raise NotImplementedError.new
      end

      # returns boolean if the test is successful
      def test
        raise NotImplementedError.new
      end

      # return the gateway of the bmc device
      def gateway
        raise NotImplementedError.new
      end

      # return the netmask of the bmc device
      def netmask
        raise NotImplementedError.new
      end

      protected
      attr_reader :host
    end
  end
end
