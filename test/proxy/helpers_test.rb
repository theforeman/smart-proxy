require 'test_helper'

require 'proxy/helpers'

class HelperTester
  include Proxy::Helpers
end

class ProxyHelpersTest < Test::Unit::TestCase
  def build_request(content_type, input)
    env = Rack::MockRequest.env_for('http://example.com/', method: 'POST', 'CONTENT_TYPE' => content_type, input: input)
    Rack::Request.new(env)
  end

  def test_parse_json_body_different_media_type
    request = build_request('text/plain', 'Hello World')
    result = HelperTester.new.parse_json_body(request)
    assert_equal({}, result)
  end

  def test_parse_json_body_json_media_type
    request = build_request('application/json', '{"hello": "world"}')
    result = HelperTester.new.parse_json_body(request)
    assert_equal({'hello' => 'world'}, result)
  end
end
