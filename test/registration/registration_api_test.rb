require 'test_helper'
require 'registration/registration_api'

class RegistrationRegisterApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::Registration::Api.new
  end

  def authorization_header(token)
    { 'HTTP_AUTHORIZATION' => "Bearer #{token}" }
  end

  def remote_user_header(user)
    { 'HTTP_REMOTE_USER' => user }
  end

  def cache_key_separator
    Proxy::Registration::Api::CACHE_KEY_SEPARATOR
  end

  def stale_monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - Proxy::Registration::Api::REGISTRATION_SCRIPT_CACHE_TTL - 1
  end

  def setup
    @foreman_url = 'http://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
    # Clear class-level state between tests to prevent cross-test contamination
    Proxy::Registration::Api.registration_script_cache.clear
    Proxy::Registration::Api::KEY_MUTEXES.clear
  end

  def test_global_register_template
    stub_request(:get, "#{@foreman_url}/register").to_return(body: 'template')

    get "/"
    assert last_response.ok?
    assert_match('template', last_response.body)
  end

  def test_global_register_template_with_args
    stub_request(:get, "#{@foreman_url}/register?param=test").to_return(body: 'template')

    get '/', { param: 'test' }
    assert last_response.ok?
    assert_match('template', last_response.body)
  end

  def test_host_register_template
    stub_request(:post, "#{@foreman_url}/register").to_return(body: 'template')

    post '/'
    assert last_response.ok?
    assert_match('template', last_response.body)
  end

  def test_host_register_template_with_args
    stub_request(:post, "#{@foreman_url}/register").to_return(body: 'template')

    post '/', { host: { name: 'test.example.com', build: false } }
    assert last_response.ok?
    assert_match('template', last_response.body)
  end

  def test_host_register_template_with_args_using_json
    stub_request(:post, "#{@foreman_url}/register").to_return(body: 'template')

    post '/', { host: { name: 'test.example.com', build: false } }, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    assert_match('template', last_response.body)
  end

  def test_host_register_template_with_array_args
    stub_request(:post, "#{@foreman_url}/register").to_return(body: 'template')

    post '/', { host: { name: 'test.example.com', build: false, repo_data: [{repo: 'repo1', repo_gpg_key_url: 'url1'}, {repo: 'repo2', repo_gpg_key_url: 'url2'}] } }, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    assert_match('template', last_response.body)
  end

  def test_global_401
    stub_request(:get, "#{@foreman_url}/register").to_return(body: '401', status: 401, headers: { "Content-Type" => 'text/plain; charset=UTF-8' })

    get '/'
    assert last_response.unauthorized?
    assert_match('401', last_response.body)
  end

  def test_host_401
    stub_request(:post, "#{@foreman_url}/register").to_return(body: '401', status: 401, headers: { "Content-Type" => 'text/plain; charset=UTF-8' })

    post '/'
    assert last_response.unauthorized?
    assert_match('401', last_response.body)
  end

  def test_global_401_html_response
    stub_request(:get, "#{@foreman_url}/register").to_return(body: '401', status: 401, headers: { "Content-Type" => 'text/html; charset=UTF-8' })

    get '/'
    assert last_response.unauthorized?
    assert_match("echo \"Internal Server Error\"\nexit 1\n", last_response.body)
  end

  def test_host_401_html_response
    stub_request(:post, "#{@foreman_url}/register").to_return(body: '401', status: 401, headers: { "Content-Type" => 'text/html; charset=UTF-8' })

    post '/'
    assert last_response.unauthorized?
    assert_match("echo \"Internal Server Error\"\nexit 1\n", last_response.body)
  end

  def test_global_500
    Rack::NullLogger.any_instance.stubs(:exception)
    stub_request(:get, "#{@foreman_url}/register").to_timeout

    get '/'
    assert last_response.server_error?
    assert_match("echo \"Internal Server Error\"\nexit 1\n", last_response.body)
  end

  def test_global_register_caches_response
    stub = stub_request(:get, "#{@foreman_url}/register").to_return(body: 'template')

    2.times do
      get '/'
      assert last_response.ok?
      assert_match('template', last_response.body)
    end

    assert_requested stub, times: 1
  end

  def test_global_register_cache_key_is_parameter_order_independent
    # Cache key is normalised (params sorted alphabetically), so both orderings
    # produce activation_keys=rhel9&owner=Default_Organization and share one entry.
    stub_request(:get, "#{@foreman_url}/register?activation_keys=rhel9&owner=Default_Organization")
      .to_return(body: 'template')

    get '/', { owner: 'Default_Organization', activation_keys: 'rhel9' }
    assert last_response.ok?

    # Different parameter order — must hit cache, not Foreman again
    get '/', { activation_keys: 'rhel9', owner: 'Default_Organization' }
    assert last_response.ok?

    assert_requested :get, "#{@foreman_url}/register?activation_keys=rhel9&owner=Default_Organization", times: 1
  end

  def test_global_register_caches_per_key
    stub_a = stub_request(:get, "#{@foreman_url}/register?key=a").to_return(body: 'template_a')
    stub_b = stub_request(:get, "#{@foreman_url}/register?key=b").to_return(body: 'template_b')

    get '/', { key: 'a' }
    assert_match('template_a', last_response.body)
    get '/', { key: 'b' }
    assert_match('template_b', last_response.body)
    # second requests — must be served from cache
    get '/', { key: 'a' }
    assert_match('template_a', last_response.body)
    get '/', { key: 'b' }
    assert_match('template_b', last_response.body)

    assert_requested stub_a, times: 1
    assert_requested stub_b, times: 1
  end

  def test_global_register_caches_per_authorization_header
    stub = stub_request(:get, "#{@foreman_url}/register?key=a")
           .with(headers: { 'Authorization' => 'Bearer token-1' })
           .to_return(body: 'template')

    2.times do
      get '/', { key: 'a' }, authorization_header('token-1')
      assert last_response.ok?
      assert_match('template', last_response.body)
    end

    assert_requested stub, times: 1
  end

  def test_global_register_separates_cache_by_authorization_header
    stub_token_1 = stub_request(:get, "#{@foreman_url}/register?key=a")
                   .with(headers: { 'Authorization' => 'Bearer token-1' })
                   .to_return(body: 'template-1')
    stub_token_2 = stub_request(:get, "#{@foreman_url}/register?key=a")
                   .with(headers: { 'Authorization' => 'Bearer token-2' })
                   .to_return(body: 'template-2')

    get '/', { key: 'a' }, authorization_header('token-1')
    assert last_response.ok?
    assert_match('template-1', last_response.body)

    get '/', { key: 'a' }, authorization_header('token-2')
    assert last_response.ok?
    assert_match('template-2', last_response.body)

    assert_requested stub_token_1, times: 1
    assert_requested stub_token_2, times: 1
  end

  def test_global_register_caches_per_remote_user
    stub = stub_request(:get, "#{@foreman_url}/register?key=a").to_return(body: 'template')

    2.times do
      get '/', { key: 'a' }, remote_user_header('test-user')
      assert last_response.ok?
      assert_match('template', last_response.body)
    end

    assert_requested stub, times: 1
  end

  def test_global_register_separates_cache_by_remote_user
    stub_request(:get, "#{@foreman_url}/register?key=a")
      .to_return({ body: 'template-1' }, { body: 'template-2' })

    get '/', { key: 'a' }, remote_user_header('user-1')
    assert last_response.ok?
    assert_match('template-1', last_response.body)

    get '/', { key: 'a' }, remote_user_header('user-2')
    assert last_response.ok?
    assert_match('template-2', last_response.body)
  end

  def test_global_register_separates_cache_by_auth_and_anonymous_requests
    stub_request(:get, "#{@foreman_url}/register?key=a")
      .to_return({ body: 'template-anonymous' }, { body: 'template-authenticated' })

    get '/', { key: 'a' }
    assert last_response.ok?
    assert_match('template-anonymous', last_response.body)

    get '/', { key: 'a' }, authorization_header('token-1')
    assert last_response.ok?
    assert_match('template-authenticated', last_response.body)
  end

  def test_global_register_prefers_authorization_over_remote_user_for_cache_partitioning
    stub = stub_request(:get, "#{@foreman_url}/register?key=a")
           .with(headers: { 'Authorization' => 'Bearer token-1' })
           .to_return(body: 'template')

    get '/', { key: 'a' }, authorization_header('token-1').merge(remote_user_header('user-1'))
    assert last_response.ok?
    assert_match('template', last_response.body)

    get '/', { key: 'a' }, authorization_header('token-1').merge(remote_user_header('user-2'))
    assert last_response.ok?
    assert_match('template', last_response.body)

    assert_requested stub, times: 1
  end

  def test_global_register_cache_entry_expires_after_ttl
    Proxy::Registration::Api.registration_script_cache[''] =
      Proxy::Registration::Api::CacheEntry.new('stale-template', stale_monotonic_time)
    stub = stub_request(:get, "#{@foreman_url}/register").to_return(body: 'fresh-template')

    get '/'
    assert last_response.ok?
    assert_match('fresh-template', last_response.body)
    assert_requested stub, times: 1
  end

  def test_global_register_removes_expired_cache_entry
    cache_key = "#{cache_key_separator}auth:none"
    Proxy::Registration::Api.registration_script_cache[cache_key] =
      Proxy::Registration::Api::CacheEntry.new('stale-template', stale_monotonic_time)
    stub = stub_request(:get, "#{@foreman_url}/register").to_return(body: 'fresh-template')

    get '/'

    assert last_response.ok?
    assert_match('fresh-template', last_response.body)
    assert_requested stub, times: 1
    refute_equal 'stale-template', Proxy::Registration::Api.registration_script_cache[cache_key]&.body
  end

  def test_global_register_does_not_cache_errors
    stub = stub_request(:get, "#{@foreman_url}/register").to_return(
      body: 'error', status: 500, headers: { "Content-Type" => 'text/plain' }
    )

    2.times do
      get '/'
      assert last_response.server_error?
    end

    assert_requested stub, times: 2
  end

  def test_host_500
    Rack::NullLogger.any_instance.stubs(:exception)
    stub_request(:post, "#{@foreman_url}/register").to_timeout

    post '/'
    assert last_response.server_error?
    assert_match("echo \"Internal Server Error\"\nexit 1\n", last_response.body)
  end
end
