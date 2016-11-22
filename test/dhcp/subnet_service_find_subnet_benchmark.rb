require 'benchmark_helper'

require 'dhcp_common/dhcp_common'
require 'dhcp_common/subnet'
require 'dhcp_common/subnet_service'

host_count = 200

proxy_benchmark do
  Benchmark.ips do |x|
    x.config(:time => 10, :warmup => 0)

    [1, 5, 50, 500, 5000].each do |subnet_count|
      hosts = []
      s1 = s2 = 0
      subnets = (1..subnet_count).map do |_|
        s2 += 1
        if s2 % 256 == 0
          s1 += 1
          s2 = 0
        end

        prefix = "#{s1}.#{s2}.0"
        netmask = '255.255.255.0'
        host_count.times { |c| hosts << "#{prefix}.#{c}" }
        Proxy::DHCP::Subnet.new(prefix + '.0', netmask, {})
      end

      service = Proxy::DHCP::SubnetService.initialized_instance
      subnets.each { |s| service.add_subnet(s) }

      x.report("find_subnet (#{subnet_count} subnets, #{host_count * subnet_count} hosts)") do
        hosts.each { |s| service.find_subnet(s) }
      end
    end
  end
end
