require 'ipaddr'

module Proxy
  module BMC
    # This is the interface for scanning BMC IP address ranges.
    class BaseScanner
      def initialize(args = { })
        if args.key? :address_first
          address_first = IPAddr.new args[:address_first]
          address_last  = IPAddr.new args[:address_last]
          @range = (address_first..address_last)
        elsif args.key?(:address) && args.key?(:netmask)
          @range = IPAddr.new("#{args[:address]}/#{args[:netmask]}").to_range
        else
          @range = IPAddr.new(args[:address]).to_range
        end
        # Disallow range too large
        scanner_max_range_size = max_range_size
        if @range.first(scanner_max_range_size+1).size > scanner_max_range_size
          @range = nil
          @invalid_reason = "Range too large. Batch supports only #{scanner_max_range_size} IP addresses at a time."
        end
      rescue
        @range = nil
        if args.is_a?(Hash) && args.key?(:address)
          @invalid_reason = "Invalid CIDR provided"
        else
          @invalid_reason = "Invalid IP address provided"
        end
      end

      def valid?
        @range.is_a? Range
      end

      def error_string
        @invalid_reason
      end

      def max_range_size
        Proxy::BMC::Plugin.settings.bmc_scanner_max_range_size || 65_536
      end

      # Run the scanner and return results as array
      def scan_to_list
        raise NotImplementedError.new
      end
    end
  end
end
