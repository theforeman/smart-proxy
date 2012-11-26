class Array
  # Ruby1.8 doesn't have a rotate function, so we add our own...
  def rotate n = 1
    return self if empty?
    n %= length
    self[n..-1]+self[0...n]
  end
end

