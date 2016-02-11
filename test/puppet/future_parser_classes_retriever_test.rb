require 'test_helper'
require 'puppet'
require 'puppet_proxy/puppet_plugin'
require 'puppet_proxy/initializer'
require 'puppet_proxy/environment'
require 'puppet_proxy/puppet_class'
require 'modules/puppet_proxy/class_scanner_base'
require 'puppet_proxy/class_scanner_eparser'

# this is needed in order to load (not execute!) the suite without "uninitialized constant" errors
# in environments with puppet version prior to 3.2
module Proxy::Puppet
  class ClassScannerEParser < ClassScannerBase; end
end

module ClassScannerEParserTestSuite
  def setup
    Proxy::Puppet::Plugin.load_test_settings(:puppet_conf => File.expand_path('../fixtures/puppet.conf', __FILE__))
    Proxy::Puppet::Initializer.new.reset_puppet
  end

  def test_should_find_class_in_a_manifest
    manifest = <<-EOF
    class foreman::install {
      include 'x::y'
    }
    EOF
    require 'puppet/pops'
    klasses =  Proxy::Puppet::ClassScannerEParser.new(nil).scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size

    klass = klasses.first

    assert_equal "install", klass.name
    assert_equal "foreman", klass.module
  end

  def test_should_not_file_a_class
    manifest = <<-EOF
      include 'x::y'
    EOF
    klasses =  Proxy::Puppet::ClassScannerEParser.new(nil).scan_manifest(manifest)
    assert klasses.empty?
  end

  def test_should_find_multiple_class_in_a_manifest
    manifest = <<-EOF
    class foreman::install {
      include 'x::y'
    }
    class foreman::params {
      $var = 'xyz'
    }

    EOF
    klasses =  Proxy::Puppet::ClassScannerEParser.new(nil).scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 2, klasses.size
    klasses.sort! { |k1,k2| k1.name <=> k2.name }

    klass = klasses.first

    assert_equal "install", klass.name
    assert_equal "foreman", klass.module

    klass = klasses.last

    assert_equal "params", klass.name
    assert_equal "foreman", klass.module
  end

  def test_should_scan_a_dir

    klasses =  Proxy::Puppet::ClassScannerEParser.new(nil).scan_directory('/tmp/no_such_dir')
    assert_kind_of Array, klasses
    assert klasses.empty?
  end

  def test_should_extract_parameters__no_param_parenthesis
    manifest = <<-EOF
    class foreman::install {
    }
    EOF
    klasses = Proxy::Puppet::ClassScannerEParser.new(nil).scan_manifest(manifest)
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({}, klass.params)
  end

  def test_should_extract_parameters__empty_param_parenthesis
    manifest = <<-EOF
    class foreman::install () {
    }
    EOF
    klasses = Proxy::Puppet::ClassScannerEParser.new(nil).scan_manifest(manifest)
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({}, klass.params)
  end

  def test_should_extract_parameters__single_param_no_value
    manifest = <<-EOF
    class foreman::install ($mandatory) {
    }
    EOF
    klasses = Proxy::Puppet::ClassScannerEParser.new(nil).scan_manifest(manifest)
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({'mandatory' => nil}, klass.params)
  end

  def test_should_extract_parameters__type_coverage
    # Note that all keys are string in Puppet
    manifest = <<-EOF
    class foreman::install (
      $mandatory,
      $undef = undef,
      $emptyString = '',
      $emptyStringDq = "",
      $string = "foo",
      $integer = 42 + 3,
      $float = 3.14,
      $str_interpolation = "FLOAT_$float",
      $array = ['', "", "foo", -42, 3.14],
      $hash = { unquoted => '', "quoted" => "", 42 => "integer", 3.14 => "float", '' => 'empty' },
      $complex = { array => ['','foo',42,3.14], hash => {foo=>"bar"}, mixed => [{foo=>bar},{bar=>"baz"}] }
    ) {
    }
    EOF
    klasses = Proxy::Puppet::ClassScannerEParser.new(@environment_retriever).scan_manifest(manifest)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({
                     'mandatory' => nil,
                     'undef' => '',
                     'emptyString' => '',
                     'emptyStringDq' => '',
                     'string' => 'foo',
                     'integer' => 45,
                     'float' => 3.14,
                     'str_interpolation' => 'FLOAT_${float}',
                     'array' => ['', '', 'foo', -42, 3.14],
                     # All keys must be strings
                     'hash' => { 'unquoted' => '', 'quoted' => '', '42' => 'integer', '3.14' => 'float', '' => 'empty' },
                     'complex' => { 'array' => ['','foo',42,3.14], 'hash' => {'foo'=>'bar'}, 'mixed' => [{'foo'=>'bar'},{'bar'=>'baz'}] }
                 }, klass.params)
  end

  def test_should_handle_import_in_a_manifest_without_cache
    klasses =  Proxy::Puppet::ClassScannerEParser.new(nil).scan_directory(File.expand_path('../fixtures/modules_include', __FILE__))
    assert_equal 2, klasses.size

    klass = klasses.find {|k| k.name == "sub::foo" }
    assert klass
    assert_equal "testinclude", klass.module

    assert klasses.any? {|k| k.name == "testinclude" }
  end

  def test_should_parse_puppet_classes_with_unicode_chars
    classes = Proxy::Puppet::ClassScannerEParser.new(nil).scan_directory(File.expand_path('../fixtures/with_unicode_chars', __FILE__))
    assert_equal 1, classes.size
    assert_equal "unicodetest", classes.first.name
  end

  class EnvironmentRetrieverForTesting
    def get(an_environment)
      raise "Unexpected environment name '#{an_environment}'" unless an_environment == 'first'
      ::Proxy::Puppet::Environment.new('first', [File.expand_path('../fixtures/modules_include', __FILE__)])
    end
  end
  def test_returns_classes_in_environment
    classes = Proxy::Puppet::ClassScannerEParser.new(EnvironmentRetrieverForTesting.new).classes_in_environment('first')

    assert_equal 2, classes.size
    assert classes.any? {|k| k.name == "testinclude" }
    assert classes.any? {|k| k.name == "sub::foo" }
  end

  #TODO add scans to a real puppet directory with modules
end

if Puppet::PUPPETVERSION >= '3.2'
  class FutureParserClassesRetrieverTest < Test::Unit::TestCase
    include ClassScannerEParserTestSuite
  end
end
