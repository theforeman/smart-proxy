require 'test_helper'
require 'puppet_proxy_common/environment'
require 'puppet_proxy_common/environments_retriever_base'
require 'puppet_proxy_common/errors'
require 'puppet_proxy_puppet_api/v3_environments_retriever'

class PuppetApiV3EnvironmentsRetrieverTest < Test::Unit::TestCase
  class EnvironmentApiForTesting
    attr_accessor :find_environments_response
    def find_environments
      find_environments_response
    end
  end

  def setup
    @api = PuppetApiV3EnvironmentsRetrieverTest::EnvironmentApiForTesting.new
    @retriever =  Proxy::PuppetApi::V3EnvironmentsRetriever.new(nil, nil, nil, nil, @api)
  end

  def test_api_response_parsing
    @api.find_environments_response = JSON.load(File.read(File.expand_path('../fixtures/environments_api.json', __FILE__)))

    envs = @retriever.all
    assert_equal Set.new(['production', 'example_env', 'development', 'common']), Set.new(envs.map { |e| e.name })

    expected = Set.new(['production', 'example_env', 'development', 'common'].map do |e|
      Set.new(["/etc/puppet/environments/#{e}/modules", "/etc/puppet/modules", "/usr/share/puppet/modules"])
    end)
    assert_equal expected, Set.new(envs.map { |e| Set.new(e.paths) })
  end

  def test_error_raised_if_response_has_no_environments
    @api.find_environments_response = {}
    assert_raises Proxy::Puppet::DataError do
      @retriever.all
    end
  end
end
