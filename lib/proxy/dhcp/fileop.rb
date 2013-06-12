module Proxy::DHCP::Fileop
  def open_file_and_lock filename, mode="w"
    # Store for use in the unlock method
    @filename = "#{Dir::tmpdir}/#{filename}"
    @lockfile = "#{@filename}.lock"

    # Loop if the file is locked
    Timeout::timeout(30) { sleep 0.1 while File.exists? @lockfile }

    # Touch the lock the file
    File.open(@lockfile, "w") {}

    if mode == "w"
      @file = File.new(@filename,'r+') rescue File.new(@filename,'w+')
    else
      @file = File.new(@filename, 'r')
    end
  end

  def get_index_and_lock filename
    open_file_and_lock filename

    # this returns the index in the file
    return @file.readlines.first.to_i rescue 0
  end

  def set_index_and_unlock index
    @file.reopen(@filename,'w')
    @file.write index
    @file.close
    File.delete @lockfile
  end

  def read_file_and_unlock
    @file.reopen(@filename, 'r')
    contents = @file.readlines
    @file.close
    File.delete @lockfile
    contents
  end
end
