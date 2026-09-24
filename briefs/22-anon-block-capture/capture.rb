class Reg
  def set(&h) = @h = h
  def poke(v) = @h.call(v)
end
R = Reg.new
def install(&) = R.set(&)
total = 0
install { |v| total += v }
R.poke(3)
R.poke(4)
p total
