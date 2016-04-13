require 'test_helper'
require 'puppet_proxy_common/api_request'
require 'puppet_proxy_puppet_api/v3_api_request'
require 'puppet_proxy_common/errors'
require 'puppet_proxy_common/puppet_class'
require 'puppet_proxy_puppet_api/v3_classes_retriever'

class PuppetApiv3ClassesRetrieverTest < Test::Unit::TestCase
  class ClassesRetrieverForTesting; end

  def setup
    @api = ClassesRetrieverForTesting.new
    @retriever = Proxy::PuppetApi::V3ClassesRetriever.new(nil, nil, nil, nil, @api)
  end

  def test_uses_puppet_resource_api
    Proxy::PuppetApi::ResourceTypeApiv3.any_instance.expects(:list_classes).with('test_environment', 'class').returns([])
    Proxy::PuppetApi::V3ClassesRetriever.new(nil, nil, nil, nil).classes_in_environment('test_environment')
  end

  def test_should_raise_environment_not_found_when_puppet_cannot_find_it
    @api.expects(:list_classes).raises(Proxy::Error::HttpError.new(400, "Could not find environment"))
    assert_raises(Proxy::Puppet::EnvironmentNotFound) { @retriever.classes_in_environment('test_environment') }
  end

  def test_should_re_raise_exception_on_other_errors
    @api.expects(:list_classes).raises(Proxy::Error::HttpError.new(500, "Could not find environment"))
    assert_raises(Proxy::Error::HttpError) { @retriever.classes_in_environment('test_environment') }
  end

  def test_should_surround_variable_expression_parameters_in_curvy_braces
    classes = @retriever.convert_to_proxy_var_parameter_representation([{'name' => 'dns', 'parameters' => {"localzonepath" => "$::dns::params::localzonepath"}}])
    assert_equal({"localzonepath" => "${::dns::params::localzonepath}"}, classes[0].params)
  end

  def test_should_keep_non_variable_expression_parameters_as_is
    classes = @retriever.convert_to_proxy_var_parameter_representation([{'name' => 'dns', 'parameters' => {"localzonepath" => "a_path", "a_param" => 42}}])
    assert_equal({"localzonepath" => "a_path", "a_param" => 42}, classes[0].params)
  end

  def test_should_assign_correct_class_name
    classes = @retriever.convert_to_proxy_var_parameter_representation([{'name' => 'dns', 'parameters' => {}}])
    assert_equal('dns', classes[0].name)
  end
end
