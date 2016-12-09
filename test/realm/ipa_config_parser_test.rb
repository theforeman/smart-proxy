require 'test_helper'
require 'realm_freeipa/ipa_config_parser'

class IpaConfigParserTest < Test::Unit::TestCase
  def setup
    @parser = Proxy::FreeIPARealm::IpaConfigParser.new(File.expand_path("realm.conf", File.expand_path("../", __FILE__)))
  end

  def test_should_return_uri
    assert_equal 'https://ipa.demo1.freeipa.org/ipa/xml', @parser.uri
  end

  def test_should_return_uri_host
    assert_equal 'ipa.demo1.freeipa.org', @parser.host
  end

  def test_should_return_uri_scheme
    assert_equal 'https', @parser.scheme
  end

  def test_should_return_realm
    assert_equal 'DEMO1.FREEIPA.ORG', @parser.realm
  end

  def test_should_raise_error_if_xmlrpc_uri_is_not_defined
    config = <<EOL
[global]
basedn = dc=demo1,dc=freeipa,dc=org
realm = DEMO1.FREEIPA.ORG
domain = demo1.freeipa.org
server = ipa.demo1.freeipa.org
host = lucid-nonsense
enable_ra = True
EOL
    parser = Proxy::FreeIPARealm::IpaConfigParser.new('')
    assert_raises(Exception) { parser.do_parse(StringIO.new(config)) }
  end

  def test_should_raise_error_if_realm_is_not_defined
    config = <<EOL
[global]
basedn = dc=demo1,dc=freeipa,dc=org
domain = demo1.freeipa.org
server = ipa.demo1.freeipa.org
host = lucid-nonsense
xmlrpc_uri = https://ipa.demo1.freeipa.org/ipa/xml
enable_ra = True
EOL
    parser = Proxy::FreeIPARealm::IpaConfigParser.new('')
    assert_raises(Exception) { parser.do_parse(StringIO.new(config)) }
  end
end
