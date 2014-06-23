require 'test_helper'
require 'chef_proxy/chef_plugin'
require 'chef_proxy/chef_request'
require 'webmock/test_unit'

class ChefProxyTest < Test::Unit::TestCase
  def setup
    @foreman_url = 'https://foreman.example.com'
    Proxy::SETTINGS.stubs(:foreman_url).returns(@foreman_url)
    Proxy::Chef::Plugin::settings.stubs(:chef_authenticate_nodes).returns(false)
  end

  def test_post_facts
    facts = {'fact' => "sample"}
    stub_request(:post, @foreman_url+'/api/hosts/facts')
    result = Proxy::Chef::Facts.new.post_facts(facts)

    assert(result.is_a? Net::HTTPOK)
  end

  def test_post_reports
    report = {'report' => "sample"}
    stub_request(:post, @foreman_url+'/api/reports')
    result = Proxy::Chef::Reports.new.post_report(report)

    assert(result.is_a? Net::HTTPOK)
  end
end
