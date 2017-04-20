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

      # return the SNMP community string of the bmc device
      def snmp
        raise NotImplementedError.new
      end

      # return the VLAN ID of the bmc device
      def vlanid
        raise NotImplementedError.new
      end

      # return IP source of BMC device
      def ipsrc
        raise NotImplementedError.new
      end

      # return all LAN details of BMC device
      def lanprint
        raise NotImplementedError.new
      end

      # BMC information
      def info
        raise NotImplementedError.new
      end

      # BMC GUID information
      def guid
        raise NotImplementedError.new
      end

      # BMC firmware version
      def version
        raise NotImplementedError.new
      end

      # BMC reset
      def reset
        raise NotImplementedError.new
      end

      # print all FRU information
      def frulist
        raise NotImplementedError.new
      end

      # HW manufacturer
      def manufacturer
        raise NotImplementedError.new
      end

      # Product name
      def model
        raise NotImplementedError.new
      end

      # Product serial number
      def serial
        raise NotImplementedError.new
      end

      # Asset tag
      def asset_tag
        raise NotImplementedError.new
      end

      # Sensor list
      def sensorlist
        raise NotImplementedError.new
      end

      # Sensor count
      def sensorcount
        raise NotImplementedError.new
      end

      # Sensor names
      def sensornames
        raise NotImplementedError.new
      end

      # Fan sensors
      def fanlist
        raise NotImplementedError.new
      end

      # Temparature sensors
      def templist
        raise NotImplementedError.new
      end

      # Get the readings of a particular sensor
      def sensorget(sensor)
        raise NotImplementedError.new
      end

      protected
      attr_reader :host
    end
  end
end
