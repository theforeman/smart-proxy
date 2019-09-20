module Proxy::TimeUtils
  # monotonic timers are only on Ruby 2.1+
  if defined?(Process::CLOCK_MONOTONIC)
    def time_monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  else
    def time_monotonic
      Time.now.to_f
    end
  end

  def time_spent_in_ms
    before = time_monotonic
    begin
      yield
    ensure
      after = time_monotonic
      duration = (after - before) * 1000
    end
    duration
  end
end
