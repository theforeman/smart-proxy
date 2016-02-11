require 'test_helper'
require 'json'
require 'ostruct'
require 'puppet_proxy/puppet'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/dependency_injection/container'
require 'puppet_proxy/puppet_api'
require 'puppet_proxy/environments_retriever_base'
require 'puppet_proxy/environment'
require 'puppet_proxy/puppet_class'

ENV['RACK_ENV'] = 'test'

class Proxy::Puppet::Api
  attr_reader :server
end

class PuppetApiTest < Test::Unit::TestCase
  class TestEnvironmentsRetriever < ::Proxy::Puppet::EnvironmentsRetrieverBase
    attr_reader :first, :second

    def initialize
      @first = ::Proxy::Puppet::Environment.new("first", ["path1", "path2"])
      @second = ::Proxy::Puppet::Environment.new("second", ["path3", "path4"])
    end
    def all
      [@first, @second]
    end

    def get(an_environment)
      super(an_environment)
    end
  end

  class TestClassesRetriever
    attr_reader :class_one, :class_two

    def initialize
      @class_one = ::Proxy::Puppet::PuppetClass.new("dns::install")
      @class_two = ::Proxy::Puppet::PuppetClass.new("dns", "dns_server_package" => "${::dns::params::dns_server_package}")
    end

    def classes_in_environment(an_environment)
      case an_environment
        when 'first'
          [@class_one, @class_two]
        when 'second'
          raise Proxy::Puppet::EnvironmentNotFound.new
        else
          raise "Unexpected environment name '#{an_environment}' was passed in into #classes_in_environment method."
      end
    end
  end

  include Rack::Test::Methods

  def setup
    @class_retriever = app.helpers.class_retriever = TestClassesRetriever.new
    @environment_retriever = app.helpers.environment_retriever = TestEnvironmentsRetriever.new

    @class_one = @class_retriever.class_one
    @class_two = @class_retriever.class_two
  end

  def app
    app = Proxy::Puppet::Api.new

    app.helpers.class_retriever = @class_retriever
    app.helpers.environment_retriever =  @environment_retriever

    app
  end

  def test_api_gets_puppet_environments
    get "/environments"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    assert_equal [@environment_retriever.first.name, @environment_retriever.second.name], JSON.parse(last_response.body)
  end

  def test_api_gets_single_puppet_environment
    get "/environments/#{@environment_retriever.first.name}"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal @environment_retriever.first.name, data["name"]
    assert_equal @environment_retriever.first.paths, data["paths"]
  end

  def test_api_missing_single_puppet_environment
    get "/environments/unknown"
    assert_equal 404, last_response.status
  end

  def test_api_gets_puppet_environment_classes
    get "/environments/first/classes"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)

    assert_equal({'name' => @class_one.name, 'module' => @class_one.module, 'params' => @class_one.params}, data[0]["dns::install"])
    assert_equal({'name' => @class_two.name, 'module' => @class_two.module, 'params' => @class_two.params}, data[1]["dns"])
  end

  def test_api_get_puppet_class_from_non_existing_environment
    get "/environments/second/classes"
    assert_equal 404, last_response.status
  end

  def test_puppet_setup
    setups = { "puppetrun" => "Proxy::Puppet::PuppetRun", "mcollective" => "Proxy::Puppet::MCollective",
               "puppetssh" => "Proxy::Puppet::PuppetSSH", "salt" => "Proxy::Puppet::Salt",
               "customrun" => "Proxy::Puppet::CustomRun" }

    setups.each do |k, v|
      Proxy::Puppet::Plugin.load_test_settings(:enabled => true, :puppet_provider => k)
      (api = Proxy::Puppet::Api.new!).puppet_setup
      assert_equal v, (class_name = api.server.class.inspect).encode(Encoding::UTF-8) rescue class_name
    end
  end
end
