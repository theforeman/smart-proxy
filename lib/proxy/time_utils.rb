module Proxy::TimeUtils
  def time_spent_in_ms
    before = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      yield
    ensure
      after = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      duration = (after - before) * 1000
    end
    duration
  end
end
