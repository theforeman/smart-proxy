require 'test_helper'
require 'dhcp_common/subnet'
require 'dhcp_common/record/reservation'
require 'dhcp_common/record/lease'
require 'dhcp_common/record/deleted_reservation'
require 'dhcp_common/subnet_service'
require 'dhcp_isc/isc_state_changes_observer'

class IscStateChangesObserverEventsTest < Test::Unit::TestCase
  class EventsForTesting < ::Proxy::DHCP::ISC::IscStateChangesObserver::Events
    attr_writer :last_event
  end

  def setup
    @events = EventsForTesting.new
  end

  def test_can_transition_to_started
    @events.started
    assert_equal :started, @events.last_event
  end

  def test_does_not_transition_to_started
    [:started, :stopped, :modified, :recreated].each do |event|
      @events.last_event = event
      @events.started
      assert_equal event, @events.last_event
    end
  end

  def test_always_transitions_to_stopped
    [:started, :stopped, :modified, :recreated, :none].each do |event|
      @events.last_event = event
      @events.stopped
      assert_equal :stopped, @events.last_event
    end
  end

  def test_transitions_to_modified
    [:modified, :none].each do |event|
      @events.last_event = event
      @events.modified
      assert_equal :modified, @events.last_event
    end
  end

  def test_does_not_transition_to_modified
    [:started, :stopped, :recreated].each do |event|
      @events.last_event = event
      @events.modified
      assert_equal event, @events.last_event
    end
  end

  def test_transitions_to_recreated
    [:modified, :recreated, :none].each do |event|
      @events.last_event = event
      @events.recreated
      assert_equal :recreated, @events.last_event
    end
  end

  def test_does_not_transition_to_recreated
    [:started, :stopped].each do |event|
      @events.last_event = event
      @events.recreated
      assert_equal event, @events.last_event
    end
  end

  def test_pop_resets_last_event_to_none
    @events.last_event = :started
    last_event = @events.pop
    assert_equal :started, last_event
    assert_equal :none, @events.last_event
  end
end

class StateChangesObserverTest < Test::Unit::TestCase
  class EventsForTesting < ::Proxy::DHCP::ISC::IscStateChangesObserver::Events
    attr_writer :last_event
  end

  class ObserverForTesting < ::Proxy::DHCP::ISC::IscStateChangesObserver
    attr_accessor :event_loop_active

    def pause
      @event_loop_active = false
    end
  end

  def setup
    @events = EventsForTesting.new
    @config_file = Object.new
    @leases_file = Object.new
    @service = Proxy::DHCP::SubnetService.new(Proxy::MemoryStore.new,
                                              Proxy::MemoryStore.new, Proxy::MemoryStore.new,
                                              Proxy::MemoryStore.new, Proxy::MemoryStore.new)
    @observer = ObserverForTesting.new(@config_file, @leases_file, @service, @events)

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

    assert @service.find_hosts_by_ip("192.168.0.0", "192.168.0.1")
  end

  def test_update_subnet_service_with_dhcp_records_should_delete_hosts_with_duplicate_macs_when_adding_reservations
    reservation_details = {:subnet =>  @subnet, :mac => "00:11:22:33:44:55", :ip => "192.168.0.10", :name => "test"}
    @service.add_host("192.168.0.0", ::Proxy::DHCP::Reservation.new(reservation_details))

    @observer.update_subnet_service_with_dhcp_records([::Proxy::DHCP::Reservation.new(reservation_details.merge(:ip => "192.168.0.1"))])

    assert @service.find_hosts_by_ip("192.168.0.0", "192.168.0.1")
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

  def test_start
    @observer.expects(:do_start)
    @observer.expects(:new_worker).returns(Object.new)
    @observer.start
    assert @observer.event_loop_active
    assert_not_nil @observer.worker.nil?
  end

  def test_event_loop_with_stopped_event
    @observer.event_loop_active = true
    @observer.expects(:do_stop)
    @observer.events.last_event = EventsForTesting::STOPPED
    @observer.event_loop
  end

  def test_event_loop_with_modified_event
    @observer.event_loop_active = true
    @observer.expects(:do_leases_modified)
    @observer.events.last_event = EventsForTesting::MODIFIED
    @observer.event_loop
  end

  def test_event_loop_with_recreated_event
    @observer.event_loop_active = true
    @observer.expects(:do_leases_recreated)
    @observer.events.last_event = EventsForTesting::RECREATED
    @observer.event_loop
  end

  def test_monitor_started
    @observer.expects(:load_subnets)
    @observer.expects(:update_subnet_service_with_dhcp_records)
    @config_file.expects(:hosts_and_leases).returns([])
    @observer.expects(:update_subnet_service_with_dhcp_records)
    @leases_file.expects(:hosts_and_leases).returns([])

    @observer.do_start
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

    @observer.do_leases_recreated
  end

  def test_leases_modified
    @observer.expects(:update_subnet_service_with_dhcp_records)
    @leases_file.expects(:hosts_and_leases).returns([])

    @observer.do_leases_modified
  end

  def test_monitor_stopped
    @config_file.expects(:close)
    @leases_file.expects(:close)

    @observer.do_stop
  end
end
