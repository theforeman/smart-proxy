# frozen_string_literal: true

require 'spec_helper'

# Specs for the main Provider class, which is the primary entry point for Foreman
# to interact with the DHCP provider.
# @see Proxy::DHCP::KeaApi::Provider
describe Proxy::DHCP::KeaApi::Provider do
  # The `before` block sets up the entire test environment using instance variables
  # to explicitly control the setup order and avoid `let`'s lazy-loading.
  before do
    # rubocop:disable RSpec/VerifiedDoubles
    @subnet_service = double('SubnetService')
    @client = double('Client')
    @free_ips = double('FreeIps')
    # rubocop:enable RSpec/VerifiedDoubles

    allow(@subnet_service).to receive_messages(
      load!: true,
      kea_id_map: { '192.168.1.0' => 1 },
      subnet_options: {},
      find_subnet: subnet,
      add_host: true,
      delete_host: true,
      delete_lease: true,
      find_record: nil,
      find_hosts_by_ip: [],
      find_host_by_mac: nil
    )
    allow(@free_ips).to receive(:find_free_ip).and_return('192.168.1.15')

    @provider = described_class.new(@subnet_service, @client, @free_ips)
  end

  def subnet
    Proxy::DHCP::Subnet.new(
      '192.168.1.0',
      '255.255.255.0',
      range: %w[192.168.1.10 192.168.1.20]
    )
  end

  describe '#initialize' do
    it 'loads the subnet cache on construction' do
      expect(@subnet_service).to have_received(:load!)
    end
  end

  describe '#add_record' do
    let(:options) { { 'mac' => 'aa:bb:cc:dd:ee:ff', 'hostname' => 'test-host', 'ip' => '192.168.1.15', subnet: subnet } }

    context 'when nextServer is given as an IP address' do
      it 'passes it through as next-server unchanged' do
        allow(@client).to receive(:post_command).and_return(successful_reservation_add)
        @provider.add_record(options.merge('nextServer' => '192.168.1.254'))
        expect(@client).to have_received(:post_command).with(
          'dhcp4', 'reservation-add', hash_including(reservation: hash_including('next-server': '192.168.1.254'))
        )
      end
    end

    context 'when nextServer is a hostname that cannot be resolved' do
      it 'raises a Proxy::DHCP::Error' do
        allow(@client).to receive(:post_command).and_return(successful_reservation_add)
        allow(Resolv).to receive(:getaddress).and_raise(Resolv::ResolvError)
        expect { @provider.add_record(options.merge('nextServer' => 'tftp.example.com')) }
          .to raise_error(Proxy::DHCP::Error, /resolve/)
      end
    end

    context 'when the Kea API call is successful' do
      before do
        allow(@client).to receive(:post_command).and_return(successful_reservation_add)
      end

      it 'returns a Reservation object' do
        expect(@provider.add_record(options)).to be_a(Proxy::DHCP::Reservation)
      end

      it 'assigns the correct IP to the record' do
        expect(@provider.add_record(options).ip).to eq('192.168.1.15')
      end
    end

    context 'when dns_servers option is provided' do
      let(:options_with_dns) do
        options.merge('dns_servers' => %w[8.8.8.8 8.8.4.4])
      end

      it 'includes domain-name-servers in the Kea API call' do
        allow(@client).to receive(:post_command).and_return(successful_reservation_add)
        @provider.add_record(options_with_dns)
        expect(@client).to have_received(:post_command).with(
          'dhcp4', 'reservation-add',
          hash_including(reservation: hash_including('option-data' => include(hash_including(name: 'domain-name-servers'))))
        )
      end
    end

    context 'when routers, ntp_servers and domain_name options are provided' do
      let(:options_with_all) do
        options.merge('routers' => ['192.168.1.1'], 'ntp_servers' => ['192.168.1.253'], 'domain_name' => 'example.com')
      end

      before { allow(@client).to receive(:post_command).and_return(successful_reservation_add) }

      it 'emits every mapped option in the Kea option-data' do
        @provider.add_record(options_with_all)
        expect(@client).to have_received(:post_command).with(
          'dhcp4', 'reservation-add',
          hash_including(reservation: hash_including('option-data' => include(
            hash_including(name: 'routers'), hash_including(name: 'ntp-servers'), hash_including(name: 'domain-name')
          )))
        )
      end
    end

    context 'when the Kea API returns an error' do
      it 'raises a Proxy::DHCP::Error' do
        allow(@client).to receive(:post_command).and_raise(Proxy::DHCP::Error, 'Kea API Error: Something went wrong.')
        expect { @provider.add_record(options) }.to raise_error(Proxy::DHCP::Error, /Something went wrong/)
      end
    end
  end

  describe '#del_record' do
    context 'when deleting a reservation' do
      let(:record) { Proxy::DHCP::Reservation.new('test-host', '192.168.1.5', 'aa:bb:cc:dd:ee:ff', subnet) }

      context 'when the Kea API call is successful' do
        it 'returns the deleted record' do
          allow(@client).to receive(:post_command).and_return(successful_reservation_del)
          expect(@provider.del_record(record)).to eq(record)
        end

        it 'calls reservation-del on the client' do
          allow(@client).to receive(:post_command).and_return(successful_reservation_del)
          @provider.del_record(record)
          expect(@client).to have_received(:post_command).with('dhcp4', 'reservation-del', anything)
        end
      end

      context 'when the Kea API returns an error' do
        it 'raises a Proxy::DHCP::Error' do
          allow(@client).to receive(:post_command).and_raise(Proxy::DHCP::Error, 'Kea API Error: Failed to delete.')
          expect { @provider.del_record(record) }.to raise_error(Proxy::DHCP::Error, /Failed to delete/)
        end
      end
    end

    context 'when deleting a lease' do
      let(:record) { Proxy::DHCP::Lease.new(nil, '192.168.1.11', 'ff:ee:dd:cc:bb:aa', subnet, 1_678_886_400, 1_678_890_000, 'active') }

      context 'when the Kea API call is successful' do
        it 'returns the deleted lease' do
          allow(@client).to receive(:post_command).and_return(successful_lease_del)
          expect(@provider.del_record(record)).to eq(record)
        end

        it 'calls lease4-del on the client' do
          allow(@client).to receive(:post_command).and_return(successful_lease_del)
          @provider.del_record(record)
          expect(@client).to have_received(:post_command).with('dhcp4', 'lease4-del', anything)
        end
      end

      context 'when the Kea API returns an error' do
        it 'raises a Proxy::DHCP::Error' do
          allow(@client).to receive(:post_command).and_raise(Proxy::DHCP::Error, 'Kea API Error: Failed to delete lease.')
          expect { @provider.del_record(record) }.to raise_error(Proxy::DHCP::Error, /Failed to delete lease/)
        end
      end
    end

    context 'when deleting an unsupported record type' do
      it 'raises a Proxy::DHCP::Error rather than silently succeeding' do
        expect { @provider.del_record(Object.new) }.to raise_error(Proxy::DHCP::Error, /unsupported record type/i)
      end
    end

    context 'when the Kea subnet-id is not in the cache' do
      let(:record) { Proxy::DHCP::Reservation.new('test-host', '192.168.1.5', 'aa:bb:cc:dd:ee:ff', subnet) }

      it 'raises a Proxy::DHCP::Error identifying the missing subnet-id' do
        allow(@subnet_service).to receive(:kea_id_map).and_return({})
        expect { @provider.del_record(record) }.to raise_error(Proxy::DHCP::Error, /subnet-id/)
      end
    end
  end

  describe '#load_subnet_options' do
    let(:subnet_obj) { subnet }

    context 'when subnet options are cached' do
      before do
        allow(@subnet_service).to receive(:subnet_options).and_return(
          '192.168.1.0' => {
            'next-server' => '192.168.1.254',
            'boot-file-name' => 'pxelinux.0',
            'domain-name' => 'example.com',
            'domain-name-servers' => '8.8.8.8,8.8.4.4',
            'ntp-servers' => '192.168.1.253'
          }
        )
      end

      it 'populates the subnet nextServer option' do
        @provider.load_subnet_options(subnet_obj)
        expect(subnet_obj.options[:nextServer]).to eq('192.168.1.254')
      end

      it 'populates the subnet filename option' do
        @provider.load_subnet_options(subnet_obj)
        expect(subnet_obj.options[:filename]).to eq('pxelinux.0')
      end

      it 'populates the subnet dns_servers option as an array' do
        @provider.load_subnet_options(subnet_obj)
        expect(subnet_obj.options[:dns_servers]).to eq(%w[8.8.8.8 8.8.4.4])
      end

      it 'populates the subnet ntp_servers option as an array' do
        @provider.load_subnet_options(subnet_obj)
        expect(subnet_obj.options[:ntp_servers]).to eq(%w[192.168.1.253])
      end
    end

    context 'when no subnet options are cached' do
      it 'does not modify the subnet options' do
        @provider.load_subnet_options(subnet_obj)
        expect(subnet_obj.options).not_to have_key(:nextServer)
      end
    end
  end
end
