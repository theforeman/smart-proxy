require 'fileutils'

namespace :pkg do
  desc 'Generate package source tar.bz2, supply ref=<tag> for tags'
  task :generate_source do
    File.exist?('pkg') || FileUtils.mkdir('pkg')
    ref = ENV['ref'] || 'HEAD'
    version = `git show #{ref}:VERSION`.chomp.chomp('-develop')
    raise "can't find VERSION from #{ref}" if version.empty?
    `git archive --prefix=foreman-proxy-#{version}/ #{ref} | bzip2 -9 > pkg/foreman-proxy-#{version}.tar.bz2`
  end
end
