require 'sd_notify'
require 'monitor'

module Proxy
  class SdNotifyAll
    def initialize(number)
      @pending = @total = number
      @pending_and_total_lock = Monitor.new
    end

    def status(msg, logger = nil)
      logger&.info(msg)
      SdNotify.status(msg)
    end

    def ready_all(decrement = 1)
      @pending_and_total_lock.synchronize do
        @pending -= decrement
        if @pending.zero?
          yield if block_given?
          ready
        end
      end
    end

    def total
      @pending_and_total_lock.synchronize do
        @total
      end
    end

    def pending
      @pending_and_total_lock.synchronize do
        @pending
      end
    end

    private

    def ready
      SdNotify.ready
    end
  end
end
