require 'redfish_client'
require 'bmc/base'
require 'bmc/redfish/dell'
require 'bmc/redfish/hpe'

module Proxy
  module BMC
    class Redfish < Base
      include Proxy::Log
      include Proxy::Util

      def initialize(args)
        @redfish_verify_ssl = Proxy::BMC::Plugin.settings.redfish_verify_ssl
        super
        load_vendor_overrides
      end

      def connect(args = { })
        connection = RedfishClient.new("https://#{args[:host]}/", verify: @redfish_verify_ssl, use_session: false)
        connection.login(args[:username], args[:password])
        connection
      end

      def load_vendor_overrides
        mod = case manufacturer
              when 'Dell Inc.' then :RedfishVendorOverridesDellInc
              when 'HPE'       then :RedfishVendorOverridesHPE
              else
                logger.debug "No #{manufacturer} specific overrides available - using generic Redfish calls"
                return
              end

        # Get the actual Module corresponding to the name stored in mod (based on the
        # manufacturer data returned from this Redfish interface), then extend this
        # instance of Proxy::BMC::Redfish with the methods in that module (if there is
        # one). Methods from the override module can use super, etc. as if it had been
        # a static subclass, but it is a dynamic/runtime effect.
        #
        # The manufacturer method must work without overrides -- so all vendor-specific
        # code may be delegated into override modules _except_ for in manufacturer()

        logger.debug "Extending Redfish with vendor overrides for #{manufacturer}"
        extend Kernel.const_get(mod)
      end

      def manufacturer
        system.Manufacturer
      end

      # returns boolean if the test is successful
      def test
        host.Managers.Members.any?
      rescue NoMethodError
        false
      end

      def identifystatus
        system.IndicatorLED&.downcase
      end

      def identifyon
        system.patch(payload: { 'IndicatorLED' => 'On' })
      end

      def identifyoff
        system.patch(payload: { 'IndicatorLED' => 'Off' })
      end

      def poweroff(soft = false)
        poweraction(soft ? 'GracefulShutdown' : 'ForceOff')
      end

      def powercycle
        poweraction('ForceRestart')
      end

      def poweron
        poweraction('On')
      end

      def powerstatus
        system.PowerState&.downcase
      end

      def poweron?
        powerstatus == 'on'
      end

      def poweroff?
        powerstatus == 'off'
      end

      def bootdevice
        system.Boot['BootSourceOverrideTarget']
      end

      def bootdevices
        # RedFish will tell you which devices can be put in the boot source override
        # but Foreman seems structurally arranged at present for these values to be
        # hardcoded. I can think of a few reasons to continue with that pattern. But
        # if in the future it becomes advantageous to do something more dynamic --
        # this is how to find out:
        #
        #    system.Boot['BootSourceOverrideTarget@Redfish.AllowableValues']
        #
        # There's an override for older HPs which have the list of boot devices at a
        # different spot. (see HPE vendor overrides)
        #
        # Dell gives a list like [ None, Floppy, Cd, Hdd, SDCard, Utilities,
        #                          BiosSetup, Pxe ]
        # HPE -        [ None, Floppy, Cd, Hdd, Usb, Utilities, BiosSetup, Pxe ]
        # SuperMicro - [ None, Pxe, Hdd, Diags, Cd, BiosSetup, FloppyRemovableMedia,
        #                UsbKey, UsbHdd, UsbFloppy, UsbCd, UefiCd, UefiHdd, ... ]
        #
        # For the four devices Foreman hardcodes, lucky for us all three use the same set
        # of values.
        ['pxe', 'disk', 'bios', 'cdrom']
      end

      def bootdevice=(args = { :device => nil, :reboot => false, :persistent => false })
        devmap = { 'bios'  => 'BiosSetup',
                   'cdrom' => 'Cd',
                   'disk'  => 'Hdd',
                   'pxe'   => 'Pxe' }

        system.patch(
          payload: {
            'Boot' => {
              'BootSourceOverrideTarget' => devmap[args[:device]],
              'BootSourceOverrideEnabled' => args[:persistent] ? 'Enabled' : 'Once',
            },
          })
        powercycle if args[:reboot]
      end

      def bootpxe(reboot = false, persistent = false)
        self.bootdevice = { :device => 'pxe', :reboot => reboot, :persistent => persistent }
      end

      def bootdisk(reboot = false, persistent = false)
        self.bootdevice = { :device => 'disk', :reboot => reboot, :persistent => persistent }
      end

      def bootbios(reboot = false, persistent = false)
        self.bootdevice = { :device => 'bios', :reboot => reboot, :persistent => persistent }
      end

      def bootcdrom(reboot = false, persistent = false)
        self.bootdevice = { :device => 'cdrom', :reboot => reboot, :persistent => persistent }
      end

      def ip
        bmc_nic.IPv4Addresses&.first&.[]('Address')
      end

      def mac
        bmc_nic.MACAddress
      end

      def gateway
        bmc_nic.IPv4Addresses&.first&.[]('Gateway')
      end

      def netmask
        bmc_nic.IPv4Addresses&.first&.[]('SubnetMask')
      end

      def vlanid
        vlaninfo = bmc_nic.VLAN
        return unless vlaninfo # some older Proliants don't have a VLAN setting at all.
        return unless vlaninfo.VLANEnable
        vlaninfo.VLANId
      end

      def ipsrc
        bmc_nic.IPv4Addresses&.first&.[]('AddressOrigin')
      end

      def guid
        manager.UUID
      end

      def version
        manager.FirmwareVersion
      end

      def reset(type = nil)
        logger.debug("BMC reset arg #{type.inspect} unused for Redfish - standard reset only") if type
        host.post(path: manager.Actions&.[]('#Manager.Reset')&.[]('target'), payload: { 'ResetType' => 'Reset' })
      end

      def model
        system.Model
      end

      def serial
        system.SerialNumber
      end

      def asset_tag
        system.AssetTag
      end

      protected

      attr_reader :host

      private

      def poweraction(action)
        host.post(path: system.Actions&.[]('#ComputerSystem.Reset')&.[]('target'), payload: { 'ResetType' => action })
      end

      # I haven't yet encountered a system (apart from a blade chassis, which I think
      # wouldn't be modeled in Foreman as a host?) which has multiple BMCs, managed systems,
      # or BMC NICs. But it's part of the Redfish design, so it's at least possible that
      # someone could. Warn if we encounter such a system, but try to carry on regardless.

      def manager
        managers = host.Managers&.Members
        logger.warn("Chassis has multiple BMCs? - using first") if managers.length > 1
        managers.first
      end

      def system
        systems = host.Systems&.Members
        logger.warn("BMC has multiple managed systems? - using first") if systems.length > 1
        systems.first
      end

      def bmc_nic
        nics = manager.EthernetInterfaces&.Members
        logger.warn("BMC has multiple NICs? - using first") if nics.length > 1
        nics.first
      end
    end
  end
end
