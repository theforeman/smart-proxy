require 'test/test_helper'

class ClassScannerEParserTest < Test::Unit::TestCase
  def test_should_find_class_in_a_manifest
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
    manifest = <<-EOF
    class foreman::install {
      include 'x::y'
    }
    EOF
    require 'puppet/pops'
    klasses =  Proxy::Puppet::ClassScannerEParser.scan_manifest(manifest, Puppet::Pops::Parser::Parser.new)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size

    klass = klasses.first

    assert_equal "install", klass.name
    assert_equal "foreman", klass.module
  end

  def test_should_not_file_a_class
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
    manifest = <<-EOF
      include 'x::y'
    EOF
    klasses =  Proxy::Puppet::ClassScannerEParser.scan_manifest(manifest, Puppet::Pops::Parser::Parser.new)
    assert klasses.empty?
  end

  def test_should_find_multiple_class_in_a_manifest
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
    manifest = <<-EOF
    class foreman::install {
      include 'x::y'
    }
    class foreman::params {
      $var = 'xyz'
    }

    EOF
    klasses =  Proxy::Puppet::ClassScannerEParser.scan_manifest(manifest, Puppet::Pops::Parser::Parser.new)
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
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
    klasses =  Proxy::Puppet::ClassScannerEParser.scan_directory('/tmp/no_such_dir')
    assert_kind_of Array, klasses
    assert klasses.empty?
  end

  def test_should_extract_parameters__no_param_parenthesis
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
    manifest = <<-EOF
    class foreman::install {
    }
    EOF
    klasses = Proxy::Puppet::ClassScannerEParser.scan_manifest(manifest, Puppet::Pops::Parser::Parser.new)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({}, klass.params)
  end

  def test_should_extract_parameters__empty_param_parenthesis
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
    manifest = <<-EOF
    class foreman::install () {
    }
    EOF
    klasses = Proxy::Puppet::ClassScannerEParser.scan_manifest(manifest, Puppet::Pops::Parser::Parser.new)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({}, klass.params)
  end

  def test_should_extract_parameters__single_param_no_value
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
    manifest = <<-EOF
    class foreman::install ($mandatory) {
    }
    EOF
    klasses = Proxy::Puppet::ClassScannerEParser.scan_manifest(manifest, Puppet::Pops::Parser::Parser.new)
    assert_kind_of Array, klasses
    assert_equal 1, klasses.size
    klass = klasses.first
    assert_equal({'mandatory' => nil}, klass.params)
  end

  def test_should_extract_parameters__type_coverage
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
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
    klasses = Proxy::Puppet::ClassScannerEParser.scan_manifest(manifest, Puppet::Pops::Parser::Parser.new)
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

  def test_should_handle_import_in_a_manifest
    return unless Puppet::PUPPETVERSION.to_f >= 3.2
    klasses =  Proxy::Puppet::ClassScannerEParser.scan_directory('./test/fixtures/modules_include')
    assert_kind_of Array, klasses
    assert_equal 2, klasses.size

    klass = klasses.find {|k| k.name == "sub::foo" }
    assert klass
    assert_equal "testinclude", klass.module

    klass = klasses.find {|k| k.name == "testinclude" }
    assert klass
  end

  #TODO add scans to a real puppet directory with modules

end
