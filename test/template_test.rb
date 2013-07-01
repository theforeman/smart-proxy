require 'test_helper'
require 'uri'
require 'net/http'
require 'mocha'


class TemplateTest < Test::Unit::TestCase
  def setup
    @http_mock = mock('Net::HTTPResponse')
    @http_mock.stubs(:code => '200', :message => "OK", :body => 'A template')
  end

  def test_template_requests_return_data
    Net::HTTP.any_instance.expects(:start).returns(@http_mock)
    assert_equal 'A template', Proxy::Template::Handler.get_template('provision', 'test-token')
  end

end

