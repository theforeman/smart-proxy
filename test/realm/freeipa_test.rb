# -*- coding: utf-8 -*-
require 'test_helper'
require 'realm/realm'
require 'realm/freeipa'

class FreeIPATest < Test::Unit::TestCase
  def test_ensure_utf
    return if RUBY_VERSION =~ /^1\.8/
    unicode_string = 'žluťoučký'
    malformed_string = unicode_string.dup.force_encoding('ASCII-8BIT')
    malformed_hash = { malformed_string => { malformed_string => [malformed_string, 'test'],
                                             'hello' => 'world' },
                       1 => malformed_string,
                       :key => malformed_string }
    new_hash = Proxy::Realm::FreeIPA.ensure_utf(malformed_hash)
    assert_equal({ unicode_string => { unicode_string => [ unicode_string, 'test'],
                                       'hello' => 'world' },
                   1 => unicode_string,
                   :key => unicode_string }, new_hash)

    deserialized_hash = JSON.load(JSON.pretty_generate(new_hash))
    assert_equal({ unicode_string => { unicode_string => [ unicode_string, 'test'],
                                       'hello' => 'world' },
                   '1' => unicode_string,
                   'key' => unicode_string }, deserialized_hash)
  end
end
