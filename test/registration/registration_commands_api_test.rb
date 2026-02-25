require 'test_helper'
require 'registration/registration_commands_api'

class RegistrationCommandsApiTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Proxy::Registration::CommandsApi.new
  end

  def setup
    @foreman_url = 'http://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
  end

  def test_registration_command
    expected_body = '{"registration_command":"curl ... | bash"}'
    stub_request(:post, "#{@foreman_url}/api/registration_commands")
      .to_return(body: expected_body, headers: { 'Content-Type' => 'application/json' })

    post '/'
    assert last_response.ok?
    assert_equal expected_body, last_response.body
  end

  def test_registration_command_with_json_body
    request_body = '{"registration_command":{"organization_id":1,"hostgroup_id":2}}'
    expected_body = '{"registration_command":"curl ... | bash"}'
    stub_request(:post, "#{@foreman_url}/api/registration_commands")
      .with(body: request_body)
      .to_return(body: expected_body, headers: { 'Content-Type' => 'application/json' })

    post '/', request_body, { 'CONTENT_TYPE' => 'application/json' }
    assert last_response.ok?
    assert_equal expected_body, last_response.body
  end

  def test_registration_command_401
    stub_request(:post, "#{@foreman_url}/api/registration_commands")
      .to_return(body: 'Unauthorized', status: 401)

    post '/'
    assert last_response.unauthorized?
  end

  def test_registration_command_500
    Rack::NullLogger.any_instance.stubs(:exception)
    stub_request(:post, "#{@foreman_url}/api/registration_commands").to_timeout

    post '/'
    assert last_response.server_error?
  end
end
