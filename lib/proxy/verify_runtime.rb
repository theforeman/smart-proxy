module Proxy
  class VerifyRuntime
    class << self
      # RFC5737 declares 192.0.2.0/24 as TEST-NET-1
      MOCK_IP = '192.0.2.42'

      def settings
        Proxy::SETTINGS
      end

      def verify
        {
          reverse_proxy: verify_reverse_proxy,
        }
      end

      def verify_reverse_proxy
        # It's valid if there is no Foreman URL
        return true unless settings.foreman_url

        # Only needed for templates / registration
        # TODO: make this more generic
        return true unless ::Proxy::Plugins.instance.any? { |p| p[:state] == :running && ['templates', 'registration'].include?(p[:name]) }

        foreman = Proxy::HttpRequest::ForemanRequest.new
        request = foreman.request_factory.create_get('/api/status', headers: {'X-Forwarded-For': MOCK_IP})
        response = foreman.send_request(request)

        if response.status != '200'
          logger.info("Foreman status API returned #{response.status}")
          return false
        end

        status = JSON.parse(response.body)
        unless status.key?('remote_ip')
          message = if ::Gem::Dependency.new('', '>= 3.5.0').match?('', status['version'])
                      "Foreman Proxy authentication broken"
                    else
                      "Foreman status doesn't have a remote_ip because Foreman is too old"
                    end
          logger.info(message)
          return false
        end

        status['remote_ip'] == MOCK_IP
      rescue StandardError => e
        logger.exception('Failed to verify Foreman reverse proxy setup', e)
        false
      end
    end
  end
end
