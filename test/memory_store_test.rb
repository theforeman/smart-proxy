require 'test_helper'
require 'set'

class MemoryStoreTest < Test::Unit::TestCase

  def setup
    @store = Proxy::MemoryStore.new
  end

  def test_should_return_nil_when_key_does_not_exist
    assert_equal nil, @store["key"]
  end

  def test_should_store
    @store["key"] = "value"
    assert_equal "value", @store["key"]
  end

  def test_should_delete
    @store["key"] = "value"

    assert "value", @store.delete("key")
    assert_nil @store["key"]
  end

  def test_should_return_nil_when_hierarchical_key_does_not_exist
    assert_nil @store["a", "b", "c"]
  end

  def test_should_store_a_hierarchical_key
    @store["a", "b", "c"] = "value"
    assert_equal "value", @store["a", "b", "c"]
  end

  def test_should_delete_a_hierarchical_key
    @store["a", "b", "c"] = "value"

    assert "value", @store.delete("a", "b", "c")
    assert_nil @store["a", "b", "c"]
  end

  def test_should_return_all_values_of_arrays
    @store["a", "b", "c"] = [1, 2]
    @store["a", "b", "d"] = [3, 4]
    @store["a", "e", "f"] = [5, 6]

    assert_equal [1, 2, 3, 4, 5, 6].to_set, @store.values("a").to_set
  end

  def test_should_return_all_values
    @store["a", "b", "c"] = 1
    @store["a", "b", "d"] = 3
    @store["a", "e", "f"] = 5

    assert_equal [1, 3, 5].to_set, @store.values("a").to_set
  end

  def test_should_return_all_values_under_root
    @store["a"] = 1
    @store["b", "d"] = 3
    @store["f"] = 5

    assert_equal [1, 3, 5].to_set, @store.values.to_set
  end
end
