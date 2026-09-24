class Mem
  def initialize(initial = [])
    @storage = fill(initial)
  end

  def [](i) = @storage[i]

  private

  def fill(initial)
    array = initial.dup
    0.upto(3) { |i| array[i] ||= 0 }
    array
  end
end

class Recording < Mem
  def initialize
    super
    @log = []
  end
end

p Recording.new[2]
