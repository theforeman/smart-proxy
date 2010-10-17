require 'ipaddr'

class IPAddr
  # Returns the successor to the ipaddr.
  def succ
    return self.clone.set(@addr + 1, @family)
  end

  # Compares the ipaddr with another.
  def <=>(other)
    other = coerce_other(other)

    return nil if other.family != @family

    return @addr <=> other.to_i
  end
  include Comparable

  def coerce_other(other)
    case other
    when IPAddr
      other
    when String
      self.class.new(other)
    else
      self.class.new(other, @family)
    end
  end

  # Creates a Range object for the network address.
  #
  def to_range
    begin_addr = (@addr & @mask_addr)

    case @family
    when Socket::AF_INET
      end_addr = (@addr | (IN4MASK ^ @mask_addr))
    when Socket::AF_INET6
      end_addr = (@addr | (IN6MASK ^ @mask_addr))
    else
      raise "unsupported address family"
    end

    return clone.set(begin_addr, @family)..clone.set(end_addr, @family)
  end
end
