require 'test_helper'
require 'dhcp_common/subnet'
require 'dhcp_common/record/reservation'
require 'dhcp_common/record/lease'
require 'dhcp_common/record/deleted_reservation'
require 'dhcp_common/subnet_service'
require 'dhcp_isc/isc_state_changes_observer'


class StateChangesObserverTest < Test::Unit::TestCase
  def setup
    @config_file = Object.new
    @leases_file = Object.new
    @service = Proxy::DHCP::SubnetService.new(Proxy::MemoryStore.new, Proxy::MemoryStore.new,
                                              Proxy::MemoryStore.new, Proxy::MemoryStore.new,
                                              Proxy::MemoryStore.new, Proxy::MemoryStore.new)
    @observer = ::Proxy::DHCP::ISC::IscStateChangesObserver.new(@config_file, @leases_file, @service)

    @subnet = Proxy::DHCP::Subnet.new("192.168.0.0", "255.255.255.0")
    @service.add_subnet(@subnet)
  end

  def test_update_subnet_service_with_dhcp_records_should_delete_reservations
    reservation_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test"}
    @service.add_host("192.168.0.0", ::Proxy::DHCP::Reservation.new(reservation_details))
    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::DeletedReservation.new(reservation_details)])

    assert_equal 0, @service.all_hosts.size
  end

  def test_update_subnet_service_with_dhcp_records_should_add_reservations
    reservation_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test"}
    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::Reservation.new(reservation_details)])

    assert @service.find_host_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_update_subnet_service_with_dhcp_records_should_delete_hosts_with_duplicate_macs_when_adding_reservations
    reservation_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.10", :name => "test"}
    @service.add_host("192.168.0.0", ::Proxy::DHCP::Reservation.new(reservation_details))

    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::Reservation.new(reservation_details.merge(:ip => "192.168.0.1"))])

    assert @service.find_host_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_update_subnet_service_with_dhcp_records_should_delete_hosts_with_duplicate_ips_when_adding_reservations
    reservation_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.10", :name => "test"}
    @service.add_host("192.168.0.0", ::Proxy::DHCP::Reservation.new(reservation_details))

    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::Reservation.new(reservation_details.merge(:mac => "00:11:22:33:44:66"))])

    assert @service.find_host_by_mac("192.168.0.0", "00:11:22:33:44:66")
  end

  def test_update_subnet_service_with_dhcp_records_should_add_leases
    lease_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test"}
    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::Lease.new(lease_details)])

    assert @service.find_lease_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_update_subnet_service_with_dhcp_records_should_delete_free_leases
    lease_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test"}
    @service.add_lease("192.168.0.0", ::Proxy::DHCP::Lease.new(lease_details))

    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::Lease.new(lease_details.merge(:state => 'free'))])
    assert_nil @service.find_lease_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_update_subnet_service_with_dhcp_records_should_delete_expired_leases
    lease_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.1", :name => "test"}
    @service.add_lease("192.168.0.0", ::Proxy::DHCP::Lease.new(lease_details))

    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::Lease.new(lease_details.merge(:next_state => 'free', :ends => Time.now - 60))])
    assert_nil @service.find_lease_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_update_subnet_service_with_dhcp_records_should_delete_leases_with_duplicate_macs_when_adding_leases
    lease_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.10", :name => "test"}
    @service.add_lease("192.168.0.0", ::Proxy::DHCP::Lease.new(lease_details))

    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::Lease.new(lease_details.merge(:ip => "192.168.0.1"))])

    assert @service.find_lease_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_update_subnet_service_with_dhcp_records_should_delete_leases_with_duplicate_ips_when_adding_leases
    lease_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.10", :name => "test"}
    @service.add_lease("192.168.0.0", ::Proxy::DHCP::Lease.new(lease_details))

    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::Lease.new(lease_details.merge(:mac => "00:11:22:33:44:66"))])

    assert @service.find_lease_by_mac("192.168.0.0", "00:11:22:33:44:66")
  end

  def test_monitor_started
    @observer.expects(:load_subnets)
    @observer.expects(:update_subnet_service_with_dhcp_records)
    @config_file.expects(:hosts_and_leases).returns([])
    @observer.expects(:update_subnet_service_with_dhcp_records)
    @leases_file.expects(:hosts_and_leases).returns([])

    @observer.monitor_started
  end

  def test_leases_recreated
    @config_file.expects(:close)
    @leases_file.expects(:close)

    @service.expects(:clear)

    @observer.expects(:load_subnets)
    @observer.expects(:update_subnet_service_with_dhcp_records)
    @config_file.expects(:hosts_and_leases).returns([])
    @observer.expects(:update_subnet_service_with_dhcp_records)
    @leases_file.expects(:hosts_and_leases).returns([])

    @observer.leases_recreated
  end

  def test_leases_modified
    @observer.expects(:update_subnet_service_with_dhcp_records)
    @leases_file.expects(:hosts_and_leases).returns([])

    @observer.leases_modified
  end

  def test_monitor_stopped
    @config_file.expects(:close)
    @leases_file.expects(:close)

    @observer.monitor_stopped
  end
end
