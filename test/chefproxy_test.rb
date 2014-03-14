require 'test_helper'
require 'proxy/request'
require 'webmock/test_unit'

class ChefProxyTest < Test::Unit::TestCase
  def setup
    @foreman_url = 'https://foreman.example.com'
    SETTINGS.stubs(:foreman_url).returns(@foreman_url)
    SETTINGS.stubs(:chef_authenticate_nodes).returns(false)
  end

  def test_post_facts
    facts = {'fact' => "sample"}
    stub_request(:post,@foreman_url+'/api/hosts/facts')
    result = Proxy::Request::Facts.new.post_facts(facts)

    assert(result.is_a? Net::HTTPOK)
  end

  def test_post_reports
    report = {'report' => "sample"}
    stub_request(:post,@foreman_url+'/api/reports')
    result = Proxy::Request::Reports.new.post_report(report)

    assert(result.is_a? Net::HTTPOK)
  end
end
