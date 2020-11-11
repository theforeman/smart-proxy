require 'concurrent'

class Proxy::Puppet::V3EnvironmentClassesApiClassesRetriever
  include ::Proxy::Log

  DEFAULT_CLIENT_TIMEOUT = 15
  MAX_PUPPETAPI_TIMEOUT = 300

  attr_reader :puppet_url, :ssl_ca, :ssl_cert, :ssl_key, :api_timeout

  def initialize(puppet_url, puppet_ssl_ca, puppet_ssl_cert, puppet_ssl_key, api_timeout, api = nil)
    @etag_cache = {}
    @classes_cache = {}
    @futures_cache = {}
    @ssl_ca = puppet_ssl_ca
    @ssl_cert = puppet_ssl_cert
    @ssl_key = puppet_ssl_key
    @puppet_url = puppet_url
    @api_timeout = api_timeout
    @m = Monitor.new
    @puppet_api = api || Proxy::Puppet::Apiv3
  end

  def classes_in_environment(environment)
    legacy_classes_format(get_classes(environment))
  end

  def classes_and_errors_in_environment(environment)
    classes_and_errors(get_classes(environment))
  end

  def classes_and_errors(response)
    response['files'].map do |current|
      classes = (current['classes'] || []).map do |clazz|
        parameters = clazz['params'].map do |parameter|
          if parameter['default_source'].is_a?(String) && parameter['default_source'].start_with?('$')
            to_return = parameter.dup
            to_return['default_source'] = "${#{parameter['default_source'].slice(1..-1)}}"
            to_return
          else
            parameter
          end
        end
        {'name' => clazz['name'], 'params' => parameters}
      end
      current.has_key?('error') ? current : {'path' => current['path'], 'classes' => classes}
    end
  end

  def legacy_classes_format(response)
    response['files'].map do |current|
      (current['classes'] || []).map do |manifest| # current['classes'] is nil for 'error' entities
        parameters = manifest['params'].each_with_object({}) do |parameter, all|
          parameter_value = parameter['default_literal'] || parameter['default_source']
          all[parameter['name']] = (parameter_value.is_a?(String) && parameter_value.start_with?('$')) ? "${#{parameter_value.slice(1..-1)}}" : parameter_value
        end
        ::Proxy::Puppet::PuppetClass.new(manifest['name'], parameters)
      end
    end.flatten
  end

  def get_classes(environment)
    future = async_get_classes(environment)
    cache_used = @m.synchronize { !!@etag_cache[environment] } # etags are only available when classes cache is enabled
    client_timeout = cache_used ? DEFAULT_CLIENT_TIMEOUT : api_timeout
    logger.warn("Puppet server classes cache is disabled, classes retrieval can be slow.") unless cache_used

    future.value!(client_timeout)

    raise ::Proxy::Puppet::TimeoutError, "Puppet is taking too long to respond, please try again later." if future.pending?
    future.value
  end

  def async_get_classes(environment)
    etag, classes, existing_future = @m.synchronize { [@etag_cache[environment], @classes_cache[environment], @futures_cache[environment]] }
    return existing_future unless existing_future.nil?

    future = Concurrent::Promise.new do
      begin
        response, etag = @puppet_api.new(puppet_url, ssl_ca, ssl_cert, ssl_key).list_classes(environment, etag, MAX_PUPPETAPI_TIMEOUT)
      rescue Exception => e
        @m.synchronize { @futures_cache.delete(environment) }
        logger.error "Error while retrieving puppet classes for '%s' environment" % [environment], e
        raise e
      end

      if response == Proxy::Puppet::Apiv3::NOT_MODIFIED
        @m.synchronize do
          @futures_cache.delete(environment)
          logger.debug { "Puppet cache counts: classes %d, etag %d, futures %d" % [@classes_cache.size, @etag_cache.size, @futures_cache.size] }
        end
        classes
      else
        @m.synchronize do
          @futures_cache.delete(environment)
          @etag_cache[environment] = etag
          @classes_cache[environment] = response
          logger.debug { "Puppet cache counts: classes %d, etag %d, futures %d" % [@classes_cache.size, @etag_cache.size, @futures_cache.size] }
          response
        end
      end
    end
    @m.synchronize { @futures_cache[environment] = future }

    future.execute
  end
end
