# included in various places, to check the ruby environment

# Test for 1.9
if (RUBY_VERSION.split('.').map{|s|s.to_i} <=> [1,9,0]) > 0 then
  PLATFORM = RUBY_PLATFORM
  RUBY_1_9 = true
else
  RUBY_1_9 = false
end

# Don't load rubygems in production, it's for developers
USE_GEMS = ENV['USE_GEMS'] == "false" ? false : true
