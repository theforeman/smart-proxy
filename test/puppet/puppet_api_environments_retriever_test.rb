require 'test_helper'
require 'puppet_proxy/environment'
require 'puppet_proxy/errors'
require 'puppet_proxy/v3_environments_retriever'

class PuppetV3EnvironmentsRetrieverTest < Test::Unit::TestCase
  class EnvironmentApiForTesting
    attr_accessor :find_environments_response
    def find_environments
      find_environments_response
    end
  end

  def setup
    @api = PuppetV3EnvironmentsRetrieverTest::EnvironmentApiForTesting.new
    @retriever = Proxy::Puppet::V3EnvironmentsRetriever.new(@api)
  end

  def test_api_response_parsing
    @api.find_environments_response = JSON.load(File.read(File.expand_path('fixtures/environments_api.json', __dir__)))

    envs = @retriever.all
    assert_equal Set.new(['production', 'example_env', 'development', 'common']), Set.new(envs.map(&:name))

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
