require 'test_helper'

LEASE = "lease %s {
  starts 4 %s;
  ends 4 %s;
  tstp 4 %s;
  cltt 4 %s;
  binding state active;
  next binding state free;
  hardware ethernet ec:f4:bb:c6:ca:%s;
}
"

begin
  open('dhcp_files/dhcpd.leases', 'a') do |f|
    1.times do
      1.times do |i|
        p Time.now.to_s
        now = (Time.now + 2).strftime "%Y/%m/%d %H:%M:%S"
        f.puts LEASE % ['192.168.42.100', now, now, now, now, i.to_s(16)]
        f.fsync
      end
    end
  end
end
