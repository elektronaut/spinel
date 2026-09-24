class Reg
  def initialize(x, &handler)
    @x = x
    @handler = handler
  end

  def poke(v) = @handler.call(v)
end

class Bus
  def install(&blk)
    @reg = Reg.new(1, &blk)
  end

  def poke(v) = @reg.poke(v)
end

class Box
  attr_accessor :code
end

bus = Bus.new
box = Box.new
bus.install { |value| box.code = value }
bus.poke(7)
p box.code
