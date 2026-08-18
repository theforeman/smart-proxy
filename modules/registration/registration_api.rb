require 'registration/proxy_request'

class Proxy::Registration::Api < ::Sinatra::Base
  # Needed so `logger` resolves to Proxy::LogBuffer::Decorator (which implements
  # #exception, used in the rescue blocks below) instead of Sinatra's own null
  # logger, which is a plain ::Logger with no #exception method as of Sinatra 4.
  helpers ::Proxy::Helpers

  # Cache for the global registration script (GET /register).
  #
  # The script is identical for all hosts sharing the same registration
  # parameters (org, location, hostgroup, activation keys) and auth context,
  # making it safe to serve from an in-memory cache during concurrent bulk
  # registration.
  #
  # Per-key double-checked locking prevents thundering herd while allowing
  # genuinely independent cache keys (e.g. different activation keys) to
  # fetch from Foreman in parallel.
  #
  # Only HTTP 200 responses are cached — errors are raised out of the cache
  # block so they never poison the cache. Per-key mutexes are retained and
  # reused, which keeps synchronization stable for both hot keys and failure
  # retries without racing mutex eviction against concurrent requests.
  REGISTRATION_SCRIPT_CACHE_TTL = 5 * 60 # seconds
  AUTHORIZATION_HEADER          = 'HTTP_AUTHORIZATION'.freeze
  AUTHORIZATION_KEY_PREFIX      = 'auth:authorization:'.freeze
  CACHE_KEY_SEPARATOR           = "\0".freeze
  KEY_MUTEXES                   = Concurrent::Map.new
  REMOTE_USER_HEADER            = 'HTTP_REMOTE_USER'.freeze
  REMOTE_USER_KEY_PREFIX        = 'auth:remote_user:'.freeze
  SCRIPT_CACHE                  = Concurrent::Map.new
  AUTH_NONE_KEY                 = 'auth:none'.freeze
  CacheEntry                    = Struct.new(:body, :at)

  class ScriptFetchError < StandardError
    attr_reader :response

    def initialize(response)
      super()
      @response = response
    end
  end

  class << self
    def registration_script_cache
      SCRIPT_CACHE
    end

    def key_mutex(cache_key)
      KEY_MUTEXES.compute_if_absent(cache_key) { Mutex.new }
    end
  end

  get '/' do
    registration_script
  rescue ScriptFetchError => e
    handle_response(e.response)
  rescue StandardError => e
    logger.exception "Error when rendering Global Registration Template", e
    render_error(default_error_msg)
  end

  post '/' do
    response = Proxy::Registration::ProxyRequest.new.host_register(request)
    handle_response(response)
  rescue StandardError => e
    logger.exception "Error when rendering Host Registration Template", e
    render_error(default_error_msg)
  end

  private

  def registration_script
    cache(cache_key_for_global_register) { fetch_registration_script }
  end

  def cache_key_for_global_register
    "#{normalized_query_cache_key}#{CACHE_KEY_SEPARATOR}#{auth_cache_key_component}"
  end

  def normalized_query_cache_key
    Rack::Utils.build_query(
      Rack::Utils.parse_nested_query(request.query_string).sort_by { |k, _| k }
    )
  end

  def auth_cache_key_component
    authorization = request.env[AUTHORIZATION_HEADER].to_s
    remote_user = request.env[REMOTE_USER_HEADER].to_s

    return authorization_cache_key_component(authorization) unless authorization.empty?
    return "#{REMOTE_USER_KEY_PREFIX}#{remote_user}" unless remote_user.empty?

    AUTH_NONE_KEY
  end

  def authorization_cache_key_component(authorization)
    "#{AUTHORIZATION_KEY_PREFIX}#{authorization}"
    # A SHA-256 fingerprint is also viable if we want to avoid raw credentials
    # in cache keys.
    # "#{AUTHORIZATION_KEY_PREFIX}#{Digest::SHA256.hexdigest(authorization)}"
  end

  def fetch_registration_script
    response = Proxy::Registration::ProxyRequest.new.global_register(request)
    raise ScriptFetchError, response unless response.code == '200'

    response.body
  end

  def cache(key, &block)
    value = read_registration_cache(key)
    return value if value

    cache = self.class.registration_script_cache
    mutex = self.class.key_mutex(key)
    mutex.synchronize do
      value = read_registration_cache(key)
      return value if value

      result = yield
      cache[key] = CacheEntry.new(result, monotonic_now)
      result
    ensure
      KEY_MUTEXES.delete(key) if KEY_MUTEXES[key].equal?(mutex)
    end
  end

  def read_registration_cache(cache_key)
    cache = self.class.registration_script_cache
    entry = cache[cache_key]
    return unless entry

    if (monotonic_now - entry.at) < REGISTRATION_SCRIPT_CACHE_TTL
      entry.body
    else
      cache.delete(cache_key)
      nil
    end
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def handle_response(response)
    if response.code.start_with?('2')
      response.body
    else
      message = response["content-type"].include?('text/plain') ? response.body : default_error_msg
      render_error(message, code: response.code)
    end
  end

  def render_error(message, code: 500)
    status code
    message
  end

  def default_error_msg
    "echo \"Internal Server Error\"\nexit 1\n"
  end
end
