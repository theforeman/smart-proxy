require 'date'
require 'proxy/log_buffer/ring_buffer'

# Adopted from Celluloid library (ring_buffer.rb).
# Copyright (c) 2011-2014 Tony Arcieri. Distributed under the MIT License.
# https://github.com/celluloid/celluloid/blob/0-16-stable/lib/celluloid/logging/ring_buffer.rb
module Proxy::LogBuffer

  LogRecord = Struct.new(:timestamp, :level, :message, :backtrace, :request_id) do
    def to_h
      h = {}
      self.class.members.each{|m| h[m.to_sym] = self[m]}
      h[:level] = case h[:level]
                  when ::Logger::Severity::INFO
                    :INFO
                  when ::Logger::Severity::WARN
                    :WARN
                  when ::Logger::Severity::ERROR
                    :ERROR
                  when ::Logger::Severity::FATAL
                    :FATAL
                  when ::Logger::Severity::DEBUG
                    :DEBUG
                  else
                    :UNKNOWN
                  end
      h.delete(:backtrace) unless h[:backtrace]
      h.delete(:request_id) unless h[:request_id]
      h
    end
  end

  class Buffer
    def self.instance
      @@buffer ||= Buffer.new
    end

    def initialize(size = nil, size_tail = nil, level_tail = nil)
      @mutex = Mutex.new
      @failed_modules = {}
      @main_buffer = RingBuffer.new(size || ::Proxy::SETTINGS.log_buffer.to_i)
      @tail_buffer = RingBuffer.new(size_tail || ::Proxy::SETTINGS.log_buffer_errors.to_i)
      @level_tail = level_tail || ::Logger::Severity::ERROR
    end

    def push(rec)
      @mutex.synchronize do
        rec.timestamp = Time.now.utc.to_f
        old_value = @main_buffer.push(rec)
        @tail_buffer.push(old_value) if old_value && old_value.level >= @level_tail
      end
    end

    def iterate_ascending
      @mutex.synchronize do
        @tail_buffer.iterate_ascending { |x| yield x }
        @main_buffer.iterate_ascending { |x| yield x }
      end
    end

    def iterate_descending
      @mutex.synchronize do
        @main_buffer.iterate_descending { |x| yield x }
        @tail_buffer.iterate_descending { |x| yield x }
      end
    end

    def to_a(from_timestamp = 0)
      result = []
      if from_timestamp == 0
        iterate_ascending do |x|
          result << x if x
        end
      else
        iterate_ascending do |x|
          result << x if x && x.timestamp >= from_timestamp
        end
      end
      result
    end

    # Singleton logger does not allow per-module logging, until this is fixed
    # initialization errors are kept in this explicit hash.
    def failed_module(a_module, message)
      @failed_modules[a_module] = message
    end

    def size
      @main_buffer.size
    end

    def size_tail
      @tail_buffer.size
    end

    def to_s
      "#{size}/#{size_tail}"
    end

    def info
      {
        :size => size,
        :tail_size => size_tail,
        :level => @level,
        :level_tail => @level_tail,
        :failed_modules => @failed_modules
      }
    end
  end
end
