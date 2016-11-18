require 'test_helper'
require 'benchmark/ips'

def proxy_benchmark
  GC.start
  yield
  stats = GC.stat
  puts "Memory stats"
  puts "Total objects allocated: #{stats[:total_allocated_objects]}"
  puts "Total heap pages allocated: #{stats[:total_allocated_pages]}"
end
