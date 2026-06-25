# frozen_string_literal: true

require 'spec_helper'
require 'dhcp_common/dhcp_common'

# Specs for the SubnetService, which loads DHCP configuration from the Kea API
# into an in-memory cache for the provider to use.
# @see Proxy::DHCP::KeaApi::SubnetService
describe Proxy::DHCP::KeaApi::SubnetService do
  let(:client) { instance_double(Proxy::DHCP::KeaApi::Client) }

  let(:stores) do
    {
      leases_by_ip: Proxy::MemoryStore.new,
      leases_by_mac: Proxy::MemoryStore.new,
      reservations_by_ip: Proxy::MemoryStore.new,
      reservations_by_mac: Proxy::MemoryStore.new,
      reservations_by_name: Proxy::MemoryStore.new
    }
  end

  let(:service) do
    described_class.new(client, stores[:leases_by_ip], stores[:leases_by_mac], stores[:reservations_by_ip], stores[:reservations_by_mac],
                        stores[:reservations_by_name])
  end

  before do
    allow(client).to receive(:post_command)
      .with('dhcp4', 'reservation-get-all', anything)
      .and_raise(Proxy::DHCP::Error, 'not supported')
  end

  describe '#load!' do
    before do
      allow(client).to receive(:post_command)
        .with('dhcp4', 'config-get')
        .and_return(successful_config_get)
      allow(client).to receive(:post_command)
        .with('dhcp4', 'lease4-get-all', { subnets: [1] })
        .and_return(successful_lease_get)
    end

    it 'loads one subnet into the cache' do
      service.load!
      expect(service.subnets.count).to eq(1)
    end

    it 'finds the loaded subnet by its network address' do
      service.load!
      expect(service.find_subnet('192.168.1.0')).not_to be_nil
    end

    it 'populates the kea_id_map' do
      service.load!
      expect(service.kea_id_map).to eq('192.168.1.0' => 1)
    end

    context 'when loading leases' do
      let(:lease) do
        service.load!
        leases_by_ip = service.instance_variable_get(:@leases_by_ip)
        internal_store = leases_by_ip.instance_variable_get(:@root)
        internal_store['192.168.1.0']['192.168.1.11']
      end

      it 'creates a Lease object' do
        expect(lease).to be_a(Proxy::DHCP::Lease)
      end

      it 'assigns the correct IP to the lease' do
        expect(lease.ip).to eq('192.168.1.11')
      end
    end
  end

  describe 'reservation option round-tripping' do
    before do
      allow(client).to receive(:post_command)
        .with('dhcp4', 'config-get')
        .and_return(config_get_with_options)
      allow(client).to receive(:post_command)
        .with('dhcp4', 'lease4-get-all', anything)
        .and_return({ 'leases' => [] })
    end

    let(:reservation) do
      service.load!
      reservations_by_mac = service.instance_variable_get(:@reservations_by_mac)
      internal_store = reservations_by_mac.instance_variable_get(:@root)
      internal_store['192.168.1.0']['aa:bb:cc:dd:ee:ff']
    end

    it 'preserves next-server on the reservation' do
      expect(reservation.options[:nextServer]).to eq('192.168.1.254')
    end

    it 'preserves boot-file-name on the reservation' do
      expect(reservation.options[:filename]).to eq('pxelinux.0')
    end

    it 'preserves routers on the reservation' do
      expect(reservation.options[:routers]).to eq(['192.168.1.1'])
    end

    it 'preserves dns_servers on the reservation' do
      expect(reservation.options[:dns_servers]).to eq(%w[10.0.0.1 10.0.0.2])
    end
  end

  describe 'placeholder boot values' do
    before do
      allow(client).to receive(:post_command)
        .with('dhcp4', 'config-get')
        .and_return(config_get_with_placeholders)
      allow(client).to receive(:post_command)
        .with('dhcp4', 'lease4-get-all', anything)
        .and_return({ 'leases' => [] })
      service.load!
    end

    let(:reservation) do
      internal = service.instance_variable_get(:@reservations_by_mac).instance_variable_get(:@root)
      internal['192.168.1.0']['aa:bb:cc:dd:ee:ff']
    end

    it 'does not set nextServer when Kea reports the "0.0.0.0" placeholder' do
      expect(reservation.options).not_to have_key(:nextServer)
    end

    it 'does not set filename when Kea reports an empty boot-file-name' do
      expect(reservation.options).not_to have_key(:filename)
    end

    it 'omits the placeholder next-server from cached subnet options' do
      expect(service.subnet_options['192.168.1.0']).not_to have_key('next-server')
    end

    it 'omits the empty boot-file-name from cached subnet options' do
      expect(service.subnet_options['192.168.1.0']).not_to have_key('boot-file-name')
    end
  end

  describe 'loading reservations from the hosts-database' do
    before do
      allow(client).to receive(:post_command)
        .with('dhcp4', 'config-get')
        .and_return(successful_config_get)
      allow(client).to receive(:post_command)
        .with('dhcp4', 'lease4-get-all', anything)
        .and_return({ 'leases' => [] })
      allow(client).to receive(:post_command)
        .with('dhcp4', 'reservation-get-all', anything)
        .and_return(reservation_get_all_success)
      service.load!
    end

    it 'adds a database-only reservation to the cache' do
      expect(service.find_host_by_mac('192.168.1.0', '11:22:33:44:55:66')).not_to be_nil
    end

    it 'does not duplicate a reservation already loaded from config-get' do
      internal = service.instance_variable_get(:@reservations_by_ip).instance_variable_get(:@root)
      expect(internal['192.168.1.0']['192.168.1.5'].size).to eq(1)
    end
  end

  describe 'subnet options caching' do
    before do
      allow(client).to receive(:post_command)
        .with('dhcp4', 'config-get')
        .and_return(config_get_with_options)
      allow(client).to receive(:post_command)
        .with('dhcp4', 'lease4-get-all', anything)
        .and_return({ 'leases' => [] })
      service.load!
    end

    it 'stores subnet-level next-server' do
      expect(service.subnet_options['192.168.1.0']['next-server']).to eq('192.168.1.254')
    end

    it 'stores subnet-level boot-file-name' do
      expect(service.subnet_options['192.168.1.0']['boot-file-name']).to eq('pxelinux.0')
    end

    it 'stores subnet-level domain-name-servers' do
      expect(service.subnet_options['192.168.1.0']['domain-name-servers']).to eq('8.8.8.8,8.8.4.4')
    end

    it 'stores subnet-level domain-name' do
      expect(service.subnet_options['192.168.1.0']['domain-name']).to eq('example.com')
    end
  end

  describe 'cache TTL' do
    let(:service_with_ttl) do
      described_class.new(client, stores[:leases_by_ip], stores[:leases_by_mac], stores[:reservations_by_ip],
                          stores[:reservations_by_mac], stores[:reservations_by_name], cache_ttl: 30)
    end

    before do
      allow(client).to receive(:post_command)
        .with('dhcp4', 'config-get')
        .and_return(successful_config_get)
      allow(client).to receive(:post_command)
        .with('dhcp4', 'lease4-get-all', anything)
        .and_return(successful_lease_get)
    end

    it 'does not reload when cache is fresh' do
      service_with_ttl.load!
      service_with_ttl.all_subnets
      expect(client).to have_received(:post_command).with('dhcp4', 'config-get').once
    end

    it 'reloads when cache is stale' do
      service_with_ttl.load!
      service_with_ttl.instance_variable_set(:@loaded_at, Time.now - 60)
      service_with_ttl.all_subnets
      expect(client).to have_received(:post_command).with('dhcp4', 'config-get').twice
    end
  end

  describe 'atomic reload' do
    before do
      allow(client).to receive(:post_command)
        .with('dhcp4', 'config-get')
        .and_return(successful_config_get)
      allow(client).to receive(:post_command)
        .with('dhcp4', 'lease4-get-all', anything)
        .and_return(successful_lease_get)
      service.load!
    end

    # The stale-triggered reload must raise but must NOT leave the cache empty:
    # data is staged off to the side and only swapped in on success, so a failed
    # fetch leaves the previous cache intact (no clear-before-fetch).
    it 'preserves the previous cache when a reload fails', :aggregate_failures do
      allow(client).to receive(:post_command)
        .with('dhcp4', 'config-get')
        .and_raise(Proxy::DHCP::Error, 'kea down')
      service.instance_variable_set(:@loaded_at, Time.now - 120)

      expect { service.all_subnets }.to raise_error(Proxy::DHCP::Error)
      expect(service.subnets.count).to eq(1)
      expect(service.find_subnet('192.168.1.0')).not_to be_nil
    end
  end

  describe 'single-flight reload' do
    before do
      @config_get_calls = 0
      counter_mutex = Mutex.new
      allow(client).to receive(:post_command).with('dhcp4', 'config-get') do
        counter_mutex.synchronize { @config_get_calls += 1 }
        sleep 0.05 # widen the window so concurrent readers overlap the reload
        successful_config_get
      end
      allow(client).to receive(:post_command)
        .with('dhcp4', 'lease4-get-all', anything)
        .and_return(successful_lease_get)
    end

    it 'reloads only once when many threads observe a stale cache' do
      service.load! # 1st config-get
      service.instance_variable_set(:@loaded_at, Time.now - 120)

      threads = Array.new(8) { Thread.new { service.all_subnets } }
      threads.each(&:join)

      # 1 initial load + exactly 1 single-flighted reload, not one per thread.
      expect(@config_get_calls).to eq(2)
    end
  end

  describe 'managed subnet filtering' do
    let(:filtered_service) do
      described_class.new(client, stores[:leases_by_ip], stores[:leases_by_mac], stores[:reservations_by_ip],
                          stores[:reservations_by_mac], stores[:reservations_by_name],
                          managed_subnets: ['192.168.1.0/24'])
    end

    before do
      allow(client).to receive(:post_command)
        .with('dhcp4', 'config-get')
        .and_return(config_get_multi_subnet)
      allow(client).to receive(:post_command)
        .with('dhcp4', 'lease4-get-all', anything)
        .and_return({ 'leases' => [] })
    end

    it 'only loads managed subnets' do
      filtered_service.load!
      expect(filtered_service.subnets.count).to eq(1)
    end

    it 'loads the matching subnet' do
      filtered_service.load!
      expect(filtered_service.find_subnet('192.168.1.0')).not_to be_nil
    end

    it 'excludes the unmanaged subnet' do
      filtered_service.load!
      expect(filtered_service.find_subnet('10.0.0.0')).to be_nil
    end

    context 'when a managed entry is a host address without a prefix' do
      let(:host_filtered_service) do
        described_class.new(client, stores[:leases_by_ip], stores[:leases_by_mac], stores[:reservations_by_ip],
                            stores[:reservations_by_mac], stores[:reservations_by_name],
                            managed_subnets: ['192.168.1.0'])
      end

      it 'still matches the subnet whose network equals that address' do
        host_filtered_service.load!
        expect(host_filtered_service.find_subnet('192.168.1.0')).not_to be_nil
      end
    end
  end
end
