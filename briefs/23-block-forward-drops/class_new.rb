class Reg
  def initialize(&h) = @h = h
  def self.make(&h) = self.new(&h)
  def poke(v) = @h.call(v)
end
p Reg.make { |v| v * 2 }.poke(21)
