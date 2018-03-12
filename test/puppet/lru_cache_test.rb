require 'test_helper'
require 'puppet_proxy_puppet_api/lru_cache'

class LRUCacheTest < Test::Unit::TestCase
  class LRUCacheForTesting < ::Proxy::PuppetApi::LRUCache
    attr_accessor :lru, :cache
  end

  def setup
    @cache = LRUCacheForTesting.new(3)
    @ll = @cache.lru
  end

  def test_empty_linked_list
    assert @ll.empty?
    assert_nil @ll.head
    assert_nil @ll.tail
  end

  def test_add_the_first_element_to_linked_list
    @ll.push(node = ::Proxy::PuppetApi::LinkedListNode.new(1, 1))

    assert_equal 1, @ll.size
    assert_equal node, @ll.head
    assert_equal node, @ll.tail
    assert_nil node.left
    assert_nil node.right
  end

  def test_add_two_elements_to_linked_list
    @ll.push(tail = ::Proxy::PuppetApi::LinkedListNode.new(1, 1))
    @ll.push(head = ::Proxy::PuppetApi::LinkedListNode.new(2, 2))

    assert_equal 2, @ll.size
    assert_equal tail, @ll.tail
    assert_equal head, @ll.head
    assert_nil head.left
    assert_equal tail, head.right
    assert_nil tail.right
    assert_equal head, tail.left
  end

  def test_add_three_elements_to_linked_list
    @ll.push(tail = ::Proxy::PuppetApi::LinkedListNode.new(1, 1))
    @ll.push(middle = ::Proxy::PuppetApi::LinkedListNode.new(2, 2))
    @ll.push(head = ::Proxy::PuppetApi::LinkedListNode.new(3, 3))

    assert_equal 3, @ll.size
    assert_equal tail, @ll.tail
    assert_equal head, @ll.head
    assert_nil head.left
    assert_equal middle, head.right
    assert_nil tail.right
    assert_equal middle, tail.left
    assert_equal head, middle.left
    assert_equal tail, middle.right
  end

  def test_remove_an_element_from_empty_linked_list
    node = @ll.pop
    assert_nil node
    assert @ll.empty?
    assert_nil @ll.head
    assert_nil @ll.tail
  end

  def test_remove_the_only_element_from_linked_list
    @ll.push(expected_node = ::Proxy::PuppetApi::LinkedListNode.new(1, 1))

    node = @ll.pop
    assert @ll.empty?
    assert_nil @ll.head
    assert_nil @ll.tail
    assert_equal expected_node, node
    assert_nil node.left
    assert_nil node.right
  end

  def test_remove_head_from_linked_list
    @ll.push(tail = ::Proxy::PuppetApi::LinkedListNode.new(1, 1))
    @ll.push(middle = ::Proxy::PuppetApi::LinkedListNode.new(2, 2))
    @ll.push(head = ::Proxy::PuppetApi::LinkedListNode.new(3, 3))
    @ll.delete(head)

    assert_equal 2, @ll.size
    assert_equal middle, @ll.head
    assert_equal tail, @ll.tail
    assert_equal tail, middle.right
    assert_nil middle.left
    assert_equal middle, tail.left
    assert_nil tail.right
  end

  def test_remove_tail_from_linked_list
    @ll.push(tail = ::Proxy::PuppetApi::LinkedListNode.new(1, 1))
    @ll.push(middle = ::Proxy::PuppetApi::LinkedListNode.new(2, 2))
    @ll.push(head = ::Proxy::PuppetApi::LinkedListNode.new(3, 3))
    @ll.delete(tail)

    assert_equal 2, @ll.size
    assert_equal middle, @ll.tail
    assert_equal head, @ll.head
    assert_equal head, middle.left
    assert_nil middle.right
    assert_equal middle, head.right
    assert_nil head.left
  end

  def test_remove_middle_element_from_linked_list
    @ll.push(tail = ::Proxy::PuppetApi::LinkedListNode.new(1, 1))
    @ll.push(middle = ::Proxy::PuppetApi::LinkedListNode.new(2, 2))
    @ll.push(head = ::Proxy::PuppetApi::LinkedListNode.new(3, 3))
    @ll.delete(middle)

    assert_equal 2, @ll.size
    assert_equal tail, @ll.tail
    assert_equal head, @ll.head
    assert_equal head, tail.left
    assert_equal tail, head.right
    assert_nil head.left
    assert_nil tail.right
  end

  def test_add_a_new_element_to_cache
    result = (@cache[1] = 1)

    assert_equal 1, result
    assert_equal 1, @cache.lru.size
    assert_equal 1, @cache.cache.size
    assert_equal 1, @cache.cache[1].value
  end

  def test_replace_an_element_in_cache
    @cache[1] = 1
    result = (@cache[1] = 2)

    assert_equal 2, result
    assert_equal 1, @cache.lru.size
    assert_equal 1, @cache.cache.size
    assert_equal 2, @cache.cache[1].value
  end

  def test_adding_elements_to_cache_under_max_capacity
    @cache[1] = 1
    @cache[2] = 2

    assert_equal 2, @cache.lru.size
    assert_equal 2, @cache.cache.size
    assert_equal 1, @cache.cache[1].value
    assert_equal 2, @cache.cache[2].value
  end

  def test_should_remove_the_oldest_element_when_adding_element_to_cache_at_max_capacity
    @cache[1] = 1
    @cache[2] = 2
    @cache[3] = 3
    @cache[4] = 4

    assert_equal 3, @cache.lru.size
    assert_equal 3, @cache.cache.size
    assert_nil @cache.cache[1]
    assert_equal 2, @cache.cache[2].value
    assert_equal 3, @cache.cache[3].value
    assert_equal 4, @cache.cache[4].value
  end
end
