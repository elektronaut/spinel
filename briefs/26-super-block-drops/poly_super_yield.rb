class PfBase
  def each_twice
    yield 1
    yield 2
  end
end
class PfA < PfBase
  def each_twice(&) = super(&)
end
class PfB < PfBase
  def each_twice(&) = super
end
[PfA, PfB].each do |k|
  o = k.new
  o.each_twice { |x| p x * 10 }
end
