module Proxy::Events

  LogEvent = Struct.new(:serial, :timestamp, :level, :message)
  BacktraceLogEvent = Struct.new(:serial, :timestamp, :level, :message, :backtrace)

  class Buffer
    def self.instance
      @@buffer ||= Buffer.new
    end

    def initialize
      @mutex = Mutex.new
      @serial = 0
      @buffers_set_up = false
    end

    def new_serial
      @serial += 1
    end

    # late initialization
    def setup_buffers(size = nil, size_tail = nil, level = nil, level_tail = nil)
      require 'proxy/settings'
      @main_buffer = RingBuffer.new(size || ::Proxy::SETTINGS.log_buffer.to_i)
      @tail_buffer = RingBuffer.new(size_tail || ::Proxy::SETTINGS.log_buffer_errors.to_i)
      @level = level || Kernel.const_get("::Logger::Severity::#{::Proxy::SETTINGS.log_buffer_level}") rescue ::Logger::Severity::INFO
      @level_tail = level_tail || ::Logger::Severity::ERROR
      @buffers_set_up = true
    end

    def push(an_event)
      setup_buffers unless @buffers_set_up
      @mutex.synchronize do
        if defined?(an_event.level) && an_event.level >= @level
          an_event.serial = new_serial
          old_value = @main_buffer.push(an_event)
          @tail_buffer.push(old_value) if old_value && old_value.level >= @level_tail
        end
      end
    end

    def iterate_ascending
      setup_buffers unless @buffers_set_up
      @mutex.synchronize do
        @tail_buffer.iterate_ascending { |x| yield x }
        @main_buffer.iterate_ascending { |x| yield x }
      end
    end

    def iterate_descending
      setup_buffers unless @buffers_set_up
      @mutex.synchronize do
        @main_buffer.iterate_descending { |x| yield x }
        @tail_buffer.iterate_descending { |x| yield x }
      end
    end

    def to_a
      result = []
      iterate_ascending { |x| result << x }
      result
    end

    def get_info
      {
        "size" => @main_buffer.size,
        "tail_size" => @tail_buffer.size,
        "level" => @level,
        "level_tail" => @level_tail
      }
    end
  end

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
    alias :<< :push

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

    def to_a
      result = []
      iterate_ascending { |x| result << x }
      result
    end
  end
end
