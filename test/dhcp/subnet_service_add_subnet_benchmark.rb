require 'benchmark_helper'

require 'dhcp_common/dhcp_common'
require 'dhcp_common/subnet'
require 'dhcp_common/subnet_service'

proxy_benchmark do
  Benchmark.ips do |x|
    x.config(:time => 10, :warmup => 0)

    [1, 5, 50, 500, 1000, 15000].each do |subnet_count|
      s1 = s2 = 0
      subnets = (1..subnet_count).map do |i|
        s2 += 1
        if s2 % 256 == 0
          s1 += 1
          s2 = 0
        end

        subnet = "#{s1}.#{s2}.0.0"
        netmask = '255.255.255.0'
        Proxy::DHCP::Subnet.new(subnet, netmask, {})
      end

      x.report("add_subnet (#{subnet_count})") do
        service = Proxy::DHCP::SubnetService.initialized_instance
        subnets.each { |s| service.add_subnet(s) }
      end
    end
  end
end
