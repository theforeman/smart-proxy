require 'concurrent'

class Proxy::PuppetApi::V3EnvironmentClassesApiClassesRetriever
  include ::Proxy::Log

  MAX_CLIENT_TIMEOUT = 15
  MAX_PUPPETAPI_TIMEOUT = 300

  attr_reader :puppet_url, :ssl_ca, :ssl_cert, :ssl_key

  def initialize(puppet_url, puppet_ssl_ca, puppet_ssl_cert, puppet_ssl_key, api = nil)
    @etag_cache = {}
    @classes_cache = {}
    @futures_cache = {}
    @ssl_ca = puppet_ssl_ca
    @ssl_cert = puppet_ssl_cert
    @ssl_key = puppet_ssl_key
    @puppet_url = puppet_url
    @m = Monitor.new
    @puppet_api = api || Proxy::PuppetApi::EnvironmentClassesApiv3
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
        parameters = manifest['params'].inject({}) do |all, parameter|
          parameter_value = parameter['default_literal'] || parameter['default_source']
          all[parameter['name']] = (parameter_value.is_a?(String) && parameter_value.start_with?('$')) ? "${#{parameter_value.slice(1..-1)}}" : parameter_value
          all
        end
        ::Proxy::Puppet::PuppetClass.new(manifest['name'], parameters)
      end
    end.flatten
  end

  def get_classes(environment)
    future = async_get_classes(environment)
    future.value!(MAX_CLIENT_TIMEOUT)

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
        @m.synchronize { @futures_cache[environment] = nil }
        logger.error("Error while retrieving puppet classes for '%s' environment" % [environment], e)
        raise e
      end

      if response == Proxy::PuppetApi::EnvironmentClassesApiv3::NOT_MODIFIED
        @m.synchronize { @futures_cache[environment] = nil }
        classes
      else
        @m.synchronize do
          @futures_cache[environment] = nil
          @etag_cache[environment] = etag
          @classes_cache[environment] = response
        end
      end
    end
    @m.synchronize { @futures_cache[environment] = future }

    future.execute
  end
end

class Proxy::PuppetApi::EnvironmentClassesCacheInitializer
  include ::Proxy::Log

  def initialize(classes_retriever, environments_retriever)
    @environments = environments_retriever
    @classes = classes_retriever
  end

  def start
    logger.info("Started puppet class cache initialization")
    Concurrent::Promise.new { @environments.all }
                       .then do |environments|
                         environments.map(&:name).map do |environment|
                           logger.debug("Initializing puppet class cache for '#{environment}' environment")
                           @classes.async_get_classes(environment)
                         end
                       end
                       .flat_map { |futures| Concurrent::Promise.all?(*futures) }
                       .then { logger.info("Finished puppet class cache initialization") }
                       .on_error { logger.error("Failed to initialize puppet class cache, will use lazy initialization instead") }
                       .execute
  end
end
