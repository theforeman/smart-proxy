require 'test_helper'
require 'puppet_proxy/environment'
require 'puppet_proxy/puppet_api_v2_environments_retriever'
require 'puppet_proxy/puppet_api_v3_environments_retriever'

module PuppetApiEnvironmentsRetrieverTestSuite
  def test_uses_environments_api
    @api_class.any_instance.expects(:find_environments).returns('environments' => [])
    @retriever.all
  end

  def test_api_response_parsing
    @api_class.any_instance.
        stubs(:find_environments).
        returns(JSON.load(File.read('./test/fixtures/environments_api.json')))

    envs = @retriever.all
    assert_equal Set.new(['production', 'example_env', 'development', 'common']), Set.new(envs.map { |e| e.name })

    expected = Set.new(['production', 'example_env', 'development', 'common'].map do |e|
      Set.new(["/etc/puppet/environments/#{e}/modules", "/etc/puppet/modules", "/usr/share/puppet/modules"])
    end)
    assert_equal expected, Set.new(envs.map { |e| Set.new(e.paths) })
  end

  def test_error_raised_if_response_has_no_environments
    @api_class.any_instance.stubs(:find_environments).returns({})
    assert_raises Proxy::Puppet::DataError do
      @retriever.all
    end
  end
end

class PuppetApiV2EnvironmentsRetrieverTest < Test::Unit::TestCase
  include PuppetApiEnvironmentsRetrieverTestSuite

  def setup
    @retriever = Proxy::Puppet::PuppetApiV2EnvironmentsRetriever.new
    @api_class = Proxy::Puppet::EnvironmentsApi
  end
end

class PuppetApiV3EnvironmentsRetrieverTest < Test::Unit::TestCase
  include PuppetApiEnvironmentsRetrieverTestSuite

  def setup
    @retriever = Proxy::Puppet::PuppetApiV3EnvironmentsRetriever.new
    @api_class = Proxy::Puppet::EnvironmentsApiv3
  end
end
