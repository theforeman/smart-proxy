module ::Proxy::PuppetCa::PuppetcaHttpApi
  class PuppetcaImpl
    extend Proxy::PuppetCa::DependencyInjection
    inject_attr :http_api_impl, :client

    def sign(certname)
      client.sign(certname)
    end

    def clean(certname)
      client.clean(certname)
    end

    # list of all certificates and their state/fingerprint
    def list
      response = client.search
      response.each_with_object({}) do |entry, hsh|
        name = entry['name']
        # serial, not_before and not_after are not available via http api
        # for puppetserver < 6.3
        # see https://tickets.puppetlabs.com/browse/SERVER-2370
        hsh[name] = {
          'state' => normalized_state(entry),
          'fingerprint' => entry['fingerprint'],
          'serial' => entry['serial_number'],
          'not_before' => entry['not_before'],
          'not_after' => entry['not_after']
        }
      end
    end

    private

    # Normalize the state to match the Puppet < 6 command line values since
    # that's what Foreman expects.
    #
    # Puppet CA API sends: requested, signed, revoked
    # Foreman expects: pending, valid, revoked
    def normalized_state(entry)
      case entry['state']
      when 'signed'
        # Versions before puppetserver 6.3 do not send not_after
        if entry['not_after'] && Time.parse(entry['not_after']) > Time.now
          'revoked'
        else
          'valid'
        end
      when 'requested'
        'pending'
      else
        entry['state']
      end
    end
  end
end
