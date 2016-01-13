module Proxy::LogBuffer
  class RingBuffer
    attr_reader :size, :count

    def initialize(size)
      raise "size must be > 1" if size <= 1
      @size = size
      @start = 0
      @count = 0
      @buffer = Array.new(size)
    end

    def full?
      @count == @size
    end

    def push(value)
      stop = (@start + @count) % @size
      old_value = @buffer[stop]
      @buffer[stop] = value
      if full?
        @start = (@start + 1) % @size
        old_value
      else
        @count += 1
        nil
      end
    end

    def clear
      @buffer = Array.new(@size)
      @start = 0
      @count = 0
    end

    def iterate_ascending
      0.step(@size - 1, 1) do |size_iterator|
        element = @buffer[(@start + size_iterator) % @size]
        yield element if element
      end
    end

    def iterate_descending
      (@size - 1).step(0, -1) do |size_iterator|
        element = @buffer[(@start + size_iterator) % @size]
        yield element if element
      end
    end

    # shallow copy
    def copy(new_size)
      new_buffer = RingBuffer.new(new_size)
      iterate_ascending { |x| new_buffer.push(x) }
      new_buffer
    end

    def to_a
      result = []
      iterate_ascending { |x| result << x }
      result
    end
  end
end
