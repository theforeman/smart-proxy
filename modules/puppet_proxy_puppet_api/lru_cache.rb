module ::Proxy::PuppetApi
  class LinkedListNode
    attr_accessor :left, :right, :key, :value
    def initialize(key, value)
      @value = value
      @key = key
    end
  end

  class LinkedList
    attr_reader :head, :tail, :size

    def initialize
      @size = 0
    end

    def push(a_node)
      return create_head(a_node) if empty?
      add_node(a_node)
    end

    def pop
      delete(tail)
    end

    def delete(a_node)
      if empty?
        @head = nil
        @tail = nil
      elsif @size == 1
        @head = nil
        @tail = nil
        @size -= 1
      elsif a_node.left.nil? # head
        @head = a_node.right
        @head.left = nil
        @size -= 1
      elsif a_node.right.nil? # tail
        @tail = a_node.left
        @tail.right = nil
        @size -= 1
      else
        a_node.left.right = a_node.right
        a_node.right.left = a_node.left
        @size -= 1
      end

      a_node.left = nil unless a_node.nil?
      a_node.right = nil unless a_node.nil?
      a_node
    end

    def create_head(a_node)
      @head = a_node
      @tail = a_node
      @size = 1
    end

    def add_node(a_node)
      a_node.right = head
      a_node.left = nil
      head.left = a_node
      @head = a_node
      @size += 1
    end

    def empty?
      @size == 0
    end
  end

  class LRUCache
    def initialize(capacity)
      @capacity = capacity
      @cache = {}
      @lru = LinkedList.new
    end

    def []=(key, value)
      if @lru.size == @capacity
        tail = @lru.pop
        @cache.delete(tail.key)
      end

      old_node = @cache[key]
      @lru.delete(old_node) if old_node
      new_node = LinkedListNode.new(key, value)
      @lru.push(new_node)
      @cache[key] = new_node
      value
    end

    def [](key)
      node = @cache[key]
      return nil if node.nil?

      @lru.delete(node)
      @lru.push(node)

      node.value
    end
  end
end
