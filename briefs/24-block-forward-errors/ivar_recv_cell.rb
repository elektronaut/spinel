class Reg
  def set(&h) = @h = h
  def poke(v) = @h.call(v)
end
class Bus
  def install(&handler)
    @reg = Reg.new
    @reg.set { |v| handler.call(v) }
  end
  def poke(v) = @reg.poke(v)
end
b = Bus.new
b.install { |v| puts v }
b.poke(7)
