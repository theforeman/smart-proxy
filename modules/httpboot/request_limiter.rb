module Proxy::Httpboot
  class RequestLimiter
    WINDOW_SECONDS = 5 * 60

    def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
      @clock = clock
      @requests = {}
      @mutex = Mutex.new
      @last_cleanup = @clock.call
    end

    def allow?(remote_ip, limit)
      now = @clock.call
      cutoff = now - WINDOW_SECONDS

      @mutex.synchronize do
        if now - @last_cleanup >= WINDOW_SECONDS
          @requests.delete_if { |_, times| times.last <= cutoff }
          @last_cleanup = now
        end

        times = (@requests[remote_ip] ||= [])
        times.shift while times.first && times.first <= cutoff
        return false if times.length >= limit

        times << now
        true
      end
    end
  end
end
