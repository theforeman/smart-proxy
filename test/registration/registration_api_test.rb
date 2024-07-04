require 'test_helper'
require 'registration/registration_api'

class RegistrationRegisterApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::Registration::Api.new
  end

  def setup
    @foreman_url = 'http://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
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

  def test_host_500
    Rack::NullLogger.any_instance.stubs(:exception)
    stub_request(:post, "#{@foreman_url}/register").to_timeout

    post '/'
    assert last_response.server_error?
    assert_match("echo \"Internal Server Error\"\nexit 1\n", last_response.body)
  end
end
