module Proxy::Events

  LogEvent          = Struct.new(:serial, :timestamp, :level, :message)
  BacktraceLogEvent = Struct.new(:serial, :timestamp, :level, :message, :backtrace)

  class Buffer
    def self.instance
      @@buffer ||= Buffer.new
    end

    def initialize
      @mutex          = Mutex.new
      @serial         = 0
      @buffers_set_up = false
    end

    def new_serial
      @serial += 1
    end

    # late initialization
    def setup_buffers(size = nil, size_tail = nil, level = nil, level_tail = nil)
      require 'proxy/settings'
      @main_buffer    = RingBuffer.new(size || ::Proxy::SETTINGS.log_buffer.to_i)
      @tail_buffer    = RingBuffer.new(size_tail || ::Proxy::SETTINGS.log_buffer_errors.to_i)
      @level          = level || Kernel.const_get("::Logger::Severity::#{::Proxy::SETTINGS.log_buffer_level}") rescue ::Logger::Severity::INFO
      @level_tail     = level_tail || ::Logger::Severity::ERROR
      @buffers_set_up = true
    end

    def push(an_event)
      setup_buffers unless @buffers_set_up
      @mutex.synchronize do
        if defined?(an_event.level) && an_event.level >= @level
          an_event.serial = new_serial
          old_value       = @main_buffer.push(an_event)
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

    def info
      {
        :size       => @main_buffer.size,
        :tail_size  => @tail_buffer.size,
        :level      => @level,
        :level_tail => @level_tail
      }
    end
  end

end
