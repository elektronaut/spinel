class Mem
  def initialize(initial = [])
    @storage = fill(initial)
  end

  def clear!(initial = [])
    @storage.replace(fill(initial))
  end

  def [](i) = @storage[i]

  private

  def fill(initial)
    array = initial.dup
    0.upto(3) { |i| array[i] ||= 0 }
    array
  end
end

m = Mem.new([7])
m.clear!([5, 6])
p m[0] + m[1]
