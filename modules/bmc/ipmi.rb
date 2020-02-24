require 'rubyipmi'
require 'bmc/base'

module Proxy
  module BMC
    class IPMI < Base
      include Proxy::Log
      attr_accessor :logger, :log_level

      def self.logger
        Rubyipmi.logger
      end

      # set the logger for rubyipmi
      def self.logger=(log)
        Rubyipmi.logger = log
      end

      # returns boolean true if the specified provider is installed
      def self.installed?(provider)
        return false if provider.empty?
        # check with the lib to see if at least one provider is installed
        Rubyipmi.is_provider_installed?(provider)
      end

      # returns list of installed providers
      def self.providers_installed
        Rubyipmi.providers_installed
      end

      # returns list of supported providers by rubyipmi
      def self.providers
        Rubyipmi.providers
      end

      # Turn the ipmi device off, if its already off then nothing will happen
      # If soft=true then the ipmi will perform a graceful shutdown
      def poweroff(soft=false)
        if soft
          host.chassis.power.softShutdown
        else
          host.chassis.power.off
        end
      end

      # Turn the ipmi device on, if its already on then nothing will happen
      def poweron
        host.chassis.power.on
      end

      # Power cycle the ipmi device
      def powercycle
        host.chassis.power.cycle
      end

      # Hard reset the ipmi device
      def powerreset
        host.chassis.power.reset
      end

      def bootdevices
        ["pxe", "disk", "bios", "cdrom"]
      end

      def bootdevice
        host.chassis.config.bootdevice
      end

      def bootdevice=(args={ :device => nil, :reboot => false, :persistent => false })
        host.chassis.bootdevice(args[:device], args[:reboot], args[:persistent])
      end

      def connect(args = { })
        if args[:options].instance_of?(Hash)
          options = args[:options]
        else
          options = {} # catches nil and empty string cases
        end
        Rubyipmi.connect(args[:username], args[:password], args[:host], args[:bmc_provider], options)
      end

      # returns boolean true if connection to device is successful
      def test
        host.connection_works?
      end

      # Turn the led light on
      def identifyon
        host.chassis.identify(true)
      end

      # Turn the led light off
      def identifyoff
        host.chassis.identify(false)
      end

      # Return true or false if power is on
      def poweron?
        host.chassis.power.on?
      end

      # Return true or false if power is off
      def poweroff?
        host.chassis.power.off?
      end

      # This function will get the power state and return on or off
      def powerstatus
        host.chassis.power.status
      end

      # Get the status of the led (on or off)
      def identifystatus
        host.chassis.identifystatus
      end

      # Boot to pxe
      def bootpxe(reboot=false, persistent=false)
        host.chassis.bootpxe(reboot, persistent)
      end

      # boot to disk
      def bootdisk(reboot=false, persistent=false)
        host.chassis.bootdisk(reboot, persistent)
      end

      # boot to bios
      def bootbios(reboot=false, persistent=false)
        host.chassis.bootbios(reboot, persistent)
      end

      # boot to cdrom
      def bootcdrom(reboot=false, persistent=false)
        host.chassis.bootcdrom(reboot, persistent)
      end

      # return the ip of the bmc device
      def ip
        host.bmc.lan.ip
      end

      # return the mac of the bmc device
      def mac
        host.bmc.lan.mac
      end

      # return the gateway of the bmc device
      def gateway
        host.bmc.lan.gateway
      end

      # return the netmask of the bmc device
      def netmask
        host.bmc.lan.netmask
      end

      # return the SNMP community string of the bmc device
      def snmp
        host.bmc.lan.snmp
      end

      # return the VLAN ID of the bmc device
      def vlanid
        host.bmc.lan.vlanid
      end

      # return IP source of BMC device
      def ipsrc
        if host.bmc.lan.dhcp?
          "dhcp"
        else
          "static"
        end
      end

      # return all LAN details of BMC device
      def lanprint
        host.bmc.lan.info
      end

      # BMC information
      def info
        host.bmc.info
      end

      # BMC GUID information
      def guid
        host.bmc.guid
      end

      # BMC firmware version
      def version
        host.bmc.version
      end

      # BMC reset
      def reset(type='cold')
        host.bmc.reset(type)
      end

      # print all FRU information
      def frulist
        frulist = host.fru.list
        # Detect quirk on ipmitool or bmc_provider!=freeipmi
        if frulist.empty? && !host.is_a?(Rubyipmi::Freeipmi::Connection)
          return "Unknown error getting fru list. Try bmc_provider=freeipmi for possible quirk workaround."
        end
        frulist
      rescue Exception => e
        msg = "Error getting fru list"
        begin
          # Surprisingly, this works around an undocumented feature or bug with
          # freeipmi on IBM/Lenovo servers. The first time around, freeipmi
          # returns "invalid byte sequence in UTF-8". The second time does a
          # successful fru list.
          return host.fru.list if host.is_a?(Rubyipmi::Freeipmi::Connection)
        rescue Exception => e_retry
          return "#{msg}: #{e_retry.message}"
        end
        # Show exception caused by bmc_provider!=freeipmi
        "#{msg}: #{e.message}"
      end

      # HW manufacturer
      def manufacturer
        host.fru.manufacturer
      end

      # Product name
      def model
        host.fru.product_name
      end

      # Product serial number
      def serial
        host.fru.product_serial
      end

      # Asset tag
      def asset_tag
        host.fru.product_asset_tag
      end

      # Sensor list
      def sensorlist
        host.sensors.list
      end

      # Sensor count
      def sensorcount
        host.sensors.count
      end

      # Sensor names
      def sensornames
        host.sensors.names
      end

      # Fan sensors
      def fanlist
        host.sensors.fanlist
      end

      # Temparature sensors
      def templist
        host.sensors.templist
      end

      # Get the readings of a particular sensor
      def sensorget(sensor)
        list = host.sensors.list
        return list[sensor] if list.is_a? Hash
        nil
      end
    end
  end
end
