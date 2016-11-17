require 'test_helper'
require 'dhcp_common/dhcp_common'
require 'dhcp_common/server'
require 'dhcp_common/subnet_service'

class SubnetServiceTest < Test::Unit::TestCase
  def setup
    @subnets = {}
    @leases_ip_store = Proxy::MemoryStore.new
    @leases_mac_store = Proxy::MemoryStore.new
    @reservations_ip_store = Proxy::MemoryStore.new
    @reservations_mac_store = Proxy::MemoryStore.new
    @reservations_name_store = Proxy::MemoryStore.new

    @service = Proxy::DHCP::SubnetService.new(@leases_ip_store, @leases_mac_store, @reservations_ip_store, @reservations_mac_store, @reservations_name_store, @subnets)
  end

  def test_add_subnet
    subnet = Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0")
    @service.add_subnet(subnet)

    assert_equal 1, @service.all_subnets.size
    assert @service.all_subnets.include?(subnet)
  end

  def test_should_not_add_duplicate_subnets
    @service.add_subnet(Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"))

    assert_raise Proxy::DHCP::Error do
      @service.add_subnet(Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"))
    end
  end

  def test_bulk_add_subnets
    subnets = [Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
               Proxy::DHCP::Subnet.new("192.168.1.0", "255.255.255.0")]
    @service.add_subnets(*subnets)

    assert_equal 2, @service.all_subnets.size
    assert @service.all_subnets.include?(subnets.first)
    assert @service.all_subnets.include?(subnets.last)
  end

  def test_find_subnet
    subnets = [Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
               Proxy::DHCP::Subnet.new("192.168.1.0", "255.255.255.0")]
    @service.add_subnets(*subnets)

    assert_equal subnets.first, @service.find_subnet("192.168.0.0")
  end

  def test_find_subnet_with_cidr_mask
    subnets = [Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("192.168.0.64", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("192.168.0.128", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("192.168.0.192", "255.255.255.192")]
    @service.add_subnets(*subnets)
    assert_equal subnets[2], @service.find_subnet("192.168.0.131")
  end

  def test_find_subnet_with_cidr_mask_and_match_in_a_group_of_one_network
    subnets = [Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("192.168.0.64", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("192.168.0.192", "255.255.255.192")]
    @service.add_subnets(*subnets)
    assert_equal subnets[0], @service.find_subnet("192.168.0.10")
  end

  def test_find_subnet_with_cidr_mask_if_subnet_is_undefined
    subnets = [Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("192.168.0.64", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("192.168.0.192", "255.255.255.192")]
    @service.add_subnets(*subnets)
    assert_nil @service.find_subnet("192.168.0.131")
  end

  # the address we are looking for is in a /27 subnet
  def test_find_subnet_with_mixed_cidr_masks_deep
    subnets = [Proxy::DHCP::Subnet.new("192.0.0.0", "255.128.0.0"),
               Proxy::DHCP::Subnet.new("192.169.0.0", "255.255.0.0"),
               Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("192.168.0.64", "255.255.255.224"),
               Proxy::DHCP::Subnet.new("192.168.0.96", "255.255.255.224"),
               Proxy::DHCP::Subnet.new("192.168.0.128", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("192.168.0.192", "255.255.255.192")]
    @service.add_subnets(*subnets)
    assert_not_nil @service.find_subnet("192.168.0.100")
    assert_equal subnets[4], @service.find_subnet("192.168.0.100")
  end

  # the address is in a /6 subnet
  def test_find_subnet_with_mixed_cidr_masks_shallow
    subnets = [Proxy::DHCP::Subnet.new("188.0.0.0", "252.0.0.0"),
               Proxy::DHCP::Subnet.new("196.168.0.0", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("196.168.0.64", "255.255.255.224"),
               Proxy::DHCP::Subnet.new("196.168.0.96", "255.255.255.224"),
               Proxy::DHCP::Subnet.new("192.0.0.0", "252.0.0.0"),
               Proxy::DHCP::Subnet.new("196.168.0.128", "255.255.255.192"),
               Proxy::DHCP::Subnet.new("196.168.0.192", "255.255.255.192")]
    @service.add_subnets(*subnets)
    assert_not_nil @service.find_subnet("192.168.0.100")
    assert_equal subnets[4], @service.find_subnet("192.168.0.100")
  end

  def test_find_subnet_by_host_ip
    subnets = [Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
               Proxy::DHCP::Subnet.new("192.168.1.0", "255.255.255.0")]
    @service.add_subnets(*subnets)

    assert_equal subnets.first, @service.find_subnet("192.168.0.254")
  end

  def test_add_lease
    lease = ::Proxy::DHCP::Lease.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                     :mac => "00:11:22:33:44:55", :ip => "192.168.0.1")
    @service.add_lease("192.168.0.0", lease)

    assert_equal lease, @leases_ip_store["192.168.0.0", "192.168.0.1"]
    assert_equal lease, @leases_mac_store["192.168.0.0", "00:11:22:33:44:55"]
  end

  def test_add_reservation
    reservation = ::Proxy::DHCP::Reservation.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                     :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test")
    @service.add_host("192.168.0.0", reservation)

    assert_equal reservation, @reservations_ip_store["192.168.0.0", "192.168.0.1"]
    assert_equal reservation, @reservations_mac_store["192.168.0.0", "00:11:22:33:44:55"]
    assert_equal reservation, @reservations_name_store["test"]
  end

  def test_delete_lease
    lease = ::Proxy::DHCP::Lease.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                     :mac => "00:11:22:33:44:55", :ip => "192.168.0.1")
    @service.add_lease("192.168.0.0", lease)

    @service.delete_lease(lease)

    assert_nil @leases_ip_store["192.168.0.0", "192.168.0.1"]
    assert_nil @leases_mac_store["192.168.0.0", "00:11:22:33:44:55"]
  end

  def test_delete_host
    reservation = ::Proxy::DHCP::Reservation.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                                 :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test")
    @service.add_host("192.168.0.0", reservation)

    @service.delete_host(reservation)

    assert_nil @reservations_ip_store["192.168.0.0", "192.168.0.1"]
    assert_nil @reservations_mac_store["192.168.0.0", "00:11:22:33:44:55"]
    assert_nil @reservations_name_store["test"]
  end

  def test_all_leases
    lease1 = ::Proxy::DHCP::Lease.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                      :mac => "00:11:22:33:44:55", :ip => "192.168.0.1")
    lease2 = ::Proxy::DHCP::Lease.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.1.0", "255.255.255.0"),
                                      :mac => "00:11:22:33:44:55", :ip => "192.168.1.1")
    @service.add_lease("192.168.0.0", lease1)
    @service.add_lease("192.168.1.0", lease2)

    assert @service.all_leases("192.168.0.0").include?(lease1)
    assert @service.all_leases("192.168.1.0").include?(lease2)
    assert_equal 2, @service.all_leases.size
    assert @service.all_leases.include?(lease2)
    assert @service.all_leases.include?(lease1)
  end

  def test_all_hosts
    reservation1 = ::Proxy::DHCP::Reservation.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                                  :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test")
    reservation2 = ::Proxy::DHCP::Reservation.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.1.0", "255.255.255.0"),
                                                  :mac => "00:11:22:33:44:56", :ip => "192.168.1.1", :name => "test1")
    @service.add_host("192.168.0.0", reservation1)
    @service.add_host("192.168.1.0", reservation2)

    assert @service.all_hosts("192.168.0.0").include?(reservation1)
    assert @service.all_hosts("192.168.1.0").include?(reservation2)
    assert_equal 2, @service.all_hosts.size
    assert @service.all_hosts.include?(reservation2)
    assert @service.all_hosts.include?(reservation1)
  end

  def test_find_lease_by_ip
    lease = ::Proxy::DHCP::Lease.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                     :mac => "00:11:22:33:44:55", :ip => "192.168.0.1")
    @service.add_lease("192.168.0.0", lease)

    assert_equal lease, @service.find_lease_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_find_lease_by_ip_returns_nil_for_nonexistent_record
    assert_nil @service.find_lease_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_find_lease_by_mac
    lease = ::Proxy::DHCP::Lease.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                     :mac => "00:11:22:33:44:55", :ip => "192.168.0.1")
    @service.add_lease("192.168.0.0", lease)

    assert_equal lease, @service.find_lease_by_mac("192.168.0.0", "00:11:22:33:44:55")
  end

  def test_find_lease_by_mac_returns_nil_for_nonexistent_record
    assert_nil @service.find_lease_by_ip("192.168.0.0", "00:11:22:33:44:55")
  end

  def test_find_host_by_ip
    reservation = ::Proxy::DHCP::Reservation.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                                 :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test")
    @service.add_host("192.168.0.0", reservation)

    assert_equal reservation, @service.find_host_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_find_reservation_by_ip_returns_nil_for_nonexistent_record
    assert_nil @service.find_host_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_find_host_by_mac
    reservation = ::Proxy::DHCP::Reservation.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                                 :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test")
    @service.add_host("192.168.0.0", reservation)

    assert_equal reservation, @service.find_host_by_mac("192.168.0.0", "00:11:22:33:44:55")
  end

  def test_find_reservation_by_mac_returns_nil_for_nonexistent_record
    assert_nil @service.find_host_by_mac("192.168.0.0",  "00:11:22:33:44:55")
  end

  def test_find_host_by_name
    reservation = ::Proxy::DHCP::Reservation.new(:subnet =>  Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0"),
                                                 :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test")
    @service.add_host("192.168.0.0", reservation)

    assert_equal reservation, @service.find_host_by_hostname("test")
  end

  def test_find_reservation_by_name_returns_nil_for_nonexistent_record
    assert_nil @service.find_host_by_hostname("test")
  end
end
