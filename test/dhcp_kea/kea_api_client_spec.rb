# frozen_string_literal: true

require 'spec_helper'

# Specs for the low-level Kea API client.
# @see Proxy::DHCP::KeaApi::Client
describe Proxy::DHCP::KeaApi::Client do
  # Defines a reusable client instance for tests.
  let(:client) { described_class.new(url: 'http://localhost:8000') }

  # Tests for the client's initialisation process.
  describe '#initialize' do
    # It should create a new client instance when given a valid URL.
    it 'creates a new client with a valid URL' do
      expect(client).to be_a(described_class)
    end

    # It should raise an error if the URL is not a valid URI.
    it 'raises an ArgumentError if the URL is malformed' do
      expect { described_class.new(url: 'invalid-url') }.to raise_error(ArgumentError)
    end
  end

  # Tests for sending commands to the Kea API.
  describe '#post_command' do
    # This block tests the behaviour when the Kea API returns a successful (result: 0) response.
    context 'when the API call is successful' do
      # It should correctly parse the response and return the 'arguments' hash.
      it 'sends a command and returns the arguments hash from the response' do
        # Use WebMock to stub the HTTP POST request to our test server.
        response_body = [{ 'result' => 0, 'arguments' => { 'text' => 'Reservation added successfully.' } }]
        stub_request(:post, 'http://localhost:8000/').to_return(status: 200, body: response_body.to_json, headers: {})

        response = client.post_command('dhcp4', 'reservation-add', { 'subnet-id' => 1 })

        # The client should parse the JSON and extract the 'arguments' hash.
        expect(response).to eq({ 'text' => 'Reservation added successfully.' })
      end
    end

    # This context tests how the client handles an error response (result: 1) from the API.
    context 'when the API call returns an error' do
      # It should see the non-zero result and raise a custom error.
      it 'raises a Proxy::DHCP::Error' do
        # Stub the request to return the standard error response from our stubs.
        stub_request(:post, 'http://localhost:8000/').to_return(status: 200, body: [error_response].to_json, headers: {})

        # We expect the client to see the non-zero result and raise our custom error class.
        expect { client.post_command('dhcp4', 'reservation-add', { 'subnet-id' => 1 }) }.to raise_error(Proxy::DHCP::Error)
      end
    end
  end
end
