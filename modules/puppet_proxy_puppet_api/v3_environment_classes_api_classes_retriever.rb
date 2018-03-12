require 'concurrent'

module Proxy::PuppetApi
  DEFAULT_CLIENT_TIMEOUT = 15
  MAX_PUPPETAPI_TIMEOUT = 300
  MAX_RETRIES = 3
  RETRY_DELAY = 60

  class V3EnvironmentClassesApiClassesRetriever
    include ::Proxy::Log

    attr_reader :api_timeout, :puppet_api, :environment_classes_counter

    def initialize(api, api_timeout, environment_classes_counter, max_number_of_cached_environments)
      @etag_cache = {}
      @classes_cache = ::Proxy::PuppetApi::LRUCache.new(max_number_of_cached_environments)
      @futures_cache = {}
      @api_timeout = api_timeout
      @m = Monitor.new
      @puppet_api = api
      @environment_classes_counter = environment_classes_counter
    end

    def classes_in_environment(environment)
      legacy_classes_format(get_classes(environment))
    end

    def classes_and_errors_in_environment(environment)
      classes_and_errors(get_classes(environment))
    end

    def environment_details
      environment_classes_counter.count_all_classes
    end

    def count_classes_in_environment(environment)
      environment_classes_counter.count_classes_in_environment(environment)
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
      cache_used = @m.synchronize { !!@etag_cache[environment] } #etags are only available when classes cache is enabled
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
          response, etag = puppet_api.list_classes(environment, etag, MAX_PUPPETAPI_TIMEOUT)
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

  class EnvironmentClassesCounter
    include ::Proxy::Log
    attr_reader :environment_classes, :environments_retriever, :etag_cache,
                :update_frequency, :timeout_interval, :m

    def initialize(environment_classes_api, environments_retriever, update_frequency, timeout_interval)
      @environment_classes = environment_classes_api
      @environments_retriever = environments_retriever
      @etag_cache = Hash.new([0, nil]) # environment to [count, etag] tuple
      @update_frequency = update_frequency
      @timeout_interval = timeout_interval
      @m = Monitor.new
    end

    def count_classes_in_environment(an_environment)
      class_count, _ = m.synchronize do
        raise Proxy::Puppet::NotReady, "Initial class counters cache initialization in progress" if @first_pass_in_progress
        raise Proxy::Puppet::EnvironmentNotFound.new unless etag_cache.has_key?(an_environment)
        etag_cache[an_environment]
      end
      class_count
    end

    def count_all_classes
      m.synchronize do
        raise Proxy::Puppet::NotReady, "Initial class counters cache initialization in progress" if @first_pass_in_progress
        etag_cache.inject({}) {|all, current| all.update(current.first => {:class_count => current.last[0]})}
      end
    end

    def update_class_counts(attempt_number = 0, next_launch = 0)
      next_timer_task_launch = Time.now.to_i + update_frequency
      logger.debug("Updating puppet class counts cache")
      all_environments = environments_retriever.all.map(&:name)
      updated_class_counts = all_environments.inject({}) do |all, environment|
        count, etag = m.synchronize { etag_cache[environment] }
        response, new_etag = environment_classes.list_classes(environment, etag, MAX_PUPPETAPI_TIMEOUT)
        if response == Proxy::PuppetApi::EnvironmentClassesApiv3::NOT_MODIFIED
          all.update(environment => [count, etag])
        else
          all.update(environment => [count_classes_in_response(response), new_etag])
        end
        all
      end
      m.synchronize { @etag_cache = updated_class_counts; @first_pass_in_progress = false }
      logger.debug("Finished updating puppet class counts cache")
    rescue Exception => e
      logger.error("Error while updating puppet class counts: ", e)
      if e.kind_of?(SystemCallError) || (e.kind_of?(::Proxy::Error::HttpError) && e.status_code >= "500")
        retry_class_counts_update(attempt_number, next_timer_task_launch)
      end
    end

    def retry_class_counts_update(attempt_number, next_timer_task_launch)
      if attempt_number > 2 || Time.now.to_i + launch_delay(attempt_number + 1) >= next_timer_task_launch
        logger.error("Giving up on class count update retries")
        return
      end

      Concurrent::ScheduledTask.new(launch_delay(attempt_number + 1)) do
        logger.debug("Retrying class count updates")
        update_class_counts(attempt_number + 1, next_timer_task_launch)
      end.execute
    end

    def launch_delay(attempt_number)
      (attempt_number + 1) * RETRY_DELAY
    end

    def count_classes_in_response(list_classes_response)
      list_classes_response['files'].inject(0) do |all, current|
        all + (current['classes'] || []).size
      end
    end

    def start
      @m.synchronize { @first_pass_in_progress = true }
      @timer_task = Concurrent::TimerTask.new(:execution_interval => update_frequency,
                                              :timeout_interval => timeout_interval,
                                              :run_now => true) do
        update_class_counts
      end
      @timer_task.execute
    end

    def stop
      @timer_task.shutdown unless @timer_task.nil?
    end
  end
end
