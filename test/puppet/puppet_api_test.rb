require 'test_helper'
require 'json'
require 'puppet_proxy/puppet_class'
require 'puppet_proxy/environment'
require 'puppet_proxy/errors'

class ApiTestEnvironmentsRetriever < ::Proxy::Puppet::V3EnvironmentsRetriever
  attr_reader :first, :second

  def initialize
    @first = ::Proxy::Puppet::Environment.new("first", ["path1", "path2"])
    @second = ::Proxy::Puppet::Environment.new("second", ["path3", "path4"])
  end

  def all
    [@first, @second]
  end
end

class ApiTestClassesRetriever
  attr_reader :class_one, :class_two, :classes_and_errors_response

  def initialize
    @class_one = ::Proxy::Puppet::PuppetClass.new("dns::install")
    @class_two = ::Proxy::Puppet::PuppetClass.new("dns", "dns_server_package" => "${::dns::params::dns_server_package}")
    @classes_and_errors_response =
      [
        {"classes" => [{"name" => "dns::config", "params" => []}], "path" => "/manifests/config.pp"},
        { "classes" => [{"name" => "dns::install", "params" => []}], "path" => "/manifests/install.pp"},
        {"error" => "Syntax error at '=>' at /manifests/witherror.pp:20:19", "path" => "/manifests/witherror.pp"},
      ]
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

  def classes_and_errors_in_environment(an_environment)
    case an_environment
      when 'first'
        @classes_and_errors_response
      else
        raise Proxy::Puppet::EnvironmentNotFound
    end
  end
end

module Proxy::Puppet
  module DependencyInjection
    include Proxy::DependencyInjection::Accessors
    def container_instance
      Proxy::DependencyInjection::Container.new do |c|
        c.dependency :class_retriever_impl, ApiTestClassesRetriever
        c.dependency :environment_retriever_impl, ApiTestEnvironmentsRetriever
      end
    end
  end
end

require 'puppet_proxy/puppet_api'

ENV['RACK_ENV'] = 'test'

class PuppetTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def setup
    @class_retriever = ApiTestClassesRetriever.new
    @environment_retriever = ApiTestEnvironmentsRetriever.new

    @class_one = @class_retriever.class_one
    @class_two = @class_retriever.class_two
    @classes_and_errors_response = @class_retriever.classes_and_errors_response
  end

  def app
    app = Proxy::Puppet::Api.new
    app
  end

  def test_gets_puppet_environments
    get "/environments"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    assert_equal [@environment_retriever.first.name, @environment_retriever.second.name], JSON.parse(last_response.body)
  end

  def test_gets_single_puppet_environment
    get "/environments/#{@environment_retriever.first.name}"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)
    assert_equal @environment_retriever.first.name, data["name"]
    assert_equal @environment_retriever.first.paths, data["paths"]
  end

  def test_missing_single_puppet_environment
    get "/environments/unknown"
    assert_equal 404, last_response.status
  end

  def test_gets_puppet_environment_classes
    get "/environments/first/classes"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)

    assert_equal({'name' => @class_one.name, 'module' => @class_one.module, 'params' => @class_one.params}, data[0]["dns::install"])
    assert_equal({'name' => @class_two.name, 'module' => @class_two.module, 'params' => @class_two.params}, data[1]["dns"])
  end

  def test_gets_environment_classes_and_errors
    get "/environments/first/classes_and_errors"
    assert last_response.ok?, "Last response was not ok: #{last_response.body}"
    data = JSON.parse(last_response.body)

    assert_equal @classes_and_errors_response, data
  end

  def test_get_puppet_class_from_non_existing_environment
    get "/environments/second/classes"
    assert_equal 404, last_response.status
  end

  def test_get_classes_and_errors_from_non_existing_environment
    get "/environments/second/classes_and_errors"
    assert_equal 404, last_response.status
  end

  def test_puppet_run
    post "/run", :nodes => ['node1', 'node2']
    assert_equal 501, last_response.status
  end
end
