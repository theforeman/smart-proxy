require 'ipaddr'

class IPAddr
  # Returns a dot-decimal netmask representation
  def to_mask
    _to_string(@mask_addr)
  end

  # Returns the successor to the ipaddr.
  def succ
    self.clone.set(@addr + 1, @family)
  end

  # Compares the ipaddr with another.
  def <=>(other)
    other = coerce_other(other)

    return nil if other.family != @family

    @addr <=> other.to_i
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

    clone.set(begin_addr, @family)..clone.set(end_addr, @family)
  end
end
